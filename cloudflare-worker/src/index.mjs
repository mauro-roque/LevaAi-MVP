import { openDatabase } from "./db.mjs";
import { createApi, configuration, seed } from "./api.mjs";
import { AppError, ensure } from "./validation.mjs";
import { id } from "./auth.mjs";
import { demoPlaces } from "./maps.mjs";

const buckets = new Map();

/** Aplica cabeçalhos mínimos de segurança a todas as respostas do Worker. */
function securityHeaders(headers) {
  headers.set("X-Content-Type-Options", "nosniff");
  headers.set("X-Frame-Options", "DENY");
  headers.set("Referrer-Policy", "strict-origin-when-cross-origin");
  headers.set("Cache-Control", "no-store");
}

/** Autoriza o domínio publicado e o Flutter Web executado localmente. */
function isAllowedOrigin(origin, apiOrigin) {
  if (origin === apiOrigin) return true;
  try {
    const url = new URL(origin);
    return (
      url.protocol === "http:" &&
      ["localhost", "127.0.0.1"].includes(url.hostname)
    );
  } catch {
    return false;
  }
}

/** Limite simples por IP e rota para reduzir abuso em pontos sensíveis. */
function rateLimit(request, path) {
  const ip = request.headers.get("CF-Connecting-IP") || "unknown";
  const auth = path.startsWith("/api/auth/") && path !== "/api/auth/logout";
  const key = `${ip}:${auth ? "auth" : "api"}`,
    current = Date.now();
  const bucket = buckets.get(key) || { count: 0, until: current + 60000 };
  if (bucket.until < current) {
    bucket.count = 0;
    bucket.until = current + 60000;
  }
  bucket.count++;
  buckets.set(key, bucket);
  if (buckets.size > 2000)
    for (const [candidate, item] of buckets)
      if (item.until < current) buckets.delete(candidate);
  ensure(
    bucket.count <= (auth ? 20 : 180),
    "Muitas tentativas. Aguarde um minuto.",
    429,
  );
}

async function bodyOf(request) {
  if (!["POST", "PUT", "PATCH"].includes(request.method)) return {};
  const length = Number(request.headers.get("Content-Length") || 0);
  ensure(!length || length <= 32768, "Solicitação muito grande.", 413);
  const text = await request.text();
  ensure(text.length <= 32768, "Solicitação muito grande.", 413);
  if (!text) return {};
  try {
    const body = JSON.parse(text);
    ensure(
      body !== null && typeof body === "object" && !Array.isArray(body),
      "Corpo da solicitação inválido.",
    );
    return body;
  } catch (error) {
    if (error instanceof AppError) throw error;
    throw new AppError("JSON inválido.");
  }
}

/** Entrada HTTP do Worker: aplica segurança, banco e roteamento da API. */
export default {
  async fetch(request, env) {
    const requestId = id(),
      url = new URL(request.url),
      headers = new Headers({
        "Content-Type": "application/json; charset=utf-8",
        "X-Request-Id": requestId,
      });
    securityHeaders(headers);
    try {
      if (!url.pathname.startsWith("/api/")) return env.ASSETS.fetch(request);
      const origin = request.headers.get("Origin");
      if (origin) {
        ensure(isAllowedOrigin(origin, url.origin), "Origem não autorizada.", 403);
        headers.set("Access-Control-Allow-Origin", origin);
        headers.set("Vary", "Origin");
        headers.set(
          "Access-Control-Allow-Headers",
          "Content-Type, Authorization",
        );
        headers.set(
          "Access-Control-Allow-Methods",
          "GET, POST, PUT, PATCH, OPTIONS",
        );
      }
      if (request.method === "OPTIONS")
        return new Response(null, { status: 204, headers });
      rateLimit(request, url.pathname);
      const config = configuration(env);
      // Endpoints de disponibilidade não dependem do banco e continuam
      // informativos mesmo se o provedor estiver em manutenção.
      if (request.method === "GET" && url.pathname === "/api/health")
        return Response.json(
          { status: "ok", runtime: "cloudflare-worker" },
          { headers },
        );
      if (request.method === "GET" && url.pathname === "/api/config")
        return Response.json(
          {
            demo: config.demo,
            demoPlaces: config.demo ? demoPlaces : [],
            paymentMode: config.demo ? "demo" : "mercado_pago",
          },
          { headers },
        );
      const db = await openDatabase(env);
      try {
        if (config.demo) await seed(db);
        const api = createApi(db, config),
          body = await bodyOf(request);
        const data = await db.transaction(() =>
          api.handle({
            method: request.method,
            path: url.pathname,
            url,
            body,
            authorization: request.headers.get("Authorization"),
          }),
        );
        return Response.json(data, { headers });
      } finally {
        await db.close();
      }
    } catch (error) {
      const status = error.status || (error.code === "23505" ? 409 : 500);
      if (status === 500)
        console.error(
          JSON.stringify({
            requestId,
            message: "Falha interna",
            code: error.code || error.name,
          }),
        );
      return Response.json(
        {
          error:
            status === 500
              ? "Não foi possível concluir. Tente novamente."
              : error.message,
          requestId,
        },
        { status, headers },
      );
    }
  },
};
