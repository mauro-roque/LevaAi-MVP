import { createServer } from "node:http";
import { readFile, mkdir, stat } from "node:fs/promises";
import { resolve, extname, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { randomBytes } from "node:crypto";
import { PGlite } from "@electric-sql/pglite";
import { createWorker } from "../src/index.mjs";

const root = resolve(fileURLToPath(new URL("..", import.meta.url)));
const dataDir = resolve(root, ".local-data");
await mkdir(dataDir, { recursive: true });
const pg = new PGlite(dataDir);
await pg.exec(
  "CREATE TABLE IF NOT EXISTS public.levaai_local_migrations(name text PRIMARY KEY)",
);
for (const name of ["202609200001_base_original.sql", "202609200002_mvp.sql"]) {
  if (
    (
      await pg.query(
        "SELECT name FROM public.levaai_local_migrations WHERE name=$1",
        [name],
      )
    ).rows.length
  )
    continue;
  const sql = (
    await readFile(resolve(root, "../supabase/migrations", name), "utf8")
  ).replace('CREATE EXTENSION IF NOT EXISTS "pgcrypto";', "");
  await pg.exec(sql);
  await pg.query(
    "INSERT INTO public.levaai_local_migrations(name) VALUES($1)",
    [name],
  );
}
const worker = createWorker(async () => ({
  query: async (sql, params = []) => (await pg.query(sql, params)).rows,
  transaction: async (work) => {
    await pg.exec("BEGIN");
    try {
      const data = await work();
      await pg.exec("COMMIT");
      return data;
    } catch (e) {
      await pg.exec("ROLLBACK");
      throw e;
    }
  },
  close: async () => {},
}));
const mime = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript",
  ".json": "application/json",
  ".wasm": "application/wasm",
  ".css": "text/css",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
  ".ico": "image/x-icon",
};
const publicDir = resolve(root, "../frontEnd/leva_ai/build/web");
const env = {
  JWT_SECRET: randomBytes(48).toString("hex"),
  DEMO_MODE: "true",
  ASSETS: {
    /** Serve somente arquivos dentro do build Flutter, com fallback para a SPA. */
    async fetch(request) {
      let path = resolve(
        publicDir,
        "." + decodeURIComponent(new URL(request.url).pathname),
      );
      if (path !== publicDir && !path.startsWith(publicDir + sep))
        return new Response("Forbidden", { status: 403 });
      try {
        if ((await stat(path)).isDirectory())
          path = resolve(path, "index.html");
      } catch {
        path = resolve(publicDir, "index.html");
      }
      try {
        return new Response(await readFile(path), {
          headers: {
            "Content-Type": mime[extname(path)] || "application/octet-stream",
          },
        });
      } catch {
        return new Response("Compile o Flutter Web antes de iniciar.", {
          status: 503,
        });
      }
    },
  },
};
let queue = Promise.resolve();
const server = createServer(async (req, res) => {
  try {
    const chunks = [];
    let size = 0;
    for await (const chunk of req) {
      size += chunk.length;
      if (size > 32768) {
        res.writeHead(413);
        res.end();
        return;
      }
      chunks.push(chunk);
    }
    const request = new Request(`http://127.0.0.1:3000${req.url}`, {
      method: req.method,
      headers: req.headers,
      ...(!["GET", "HEAD"].includes(req.method)
        ? { body: Buffer.concat(chunks) }
        : {}),
    });
    // PGlite tem uma conexão. Serializar evita misturar transações locais.
    const run = () => worker.fetch(request, env);
    const task = request.url.includes("/api/") ? queue.then(run) : run();
    if (request.url.includes("/api/")) queue = task.catch(() => {});
    const response = await task;
    res.writeHead(response.status, Object.fromEntries(response.headers));
    res.end(Buffer.from(await response.arrayBuffer()));
  } catch {
    res.writeHead(500, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Falha no servidor local." }));
  }
});
server.listen(3000, "127.0.0.1", () =>
  console.log(
    "LevaAí local: http://127.0.0.1:3000 — PostgreSQL local, Pix demonstrativo.",
  ),
);
process.on("SIGINT", () =>
  server.close(async () => {
    await pg.close();
    process.exit(0);
  }),
);
