import { execFileSync } from "node:child_process";
import { cp, mkdir, rm, readFile } from "node:fs/promises";
import { resolve, dirname, sep } from "node:path";
import { fileURLToPath } from "node:url";

const workerDir = resolve(fileURLToPath(new URL("..", import.meta.url)));
const flutterDir = resolve(workerDir, "../frontEnd/leva_ai");
const source = resolve(flutterDir, "build/web");
const target = resolve(workerDir, "public");

if (!process.argv.includes("--copy-only")) {
  if (process.platform === "win32") {
    let bin;
    try {
      const flutterCommand = execFileSync("where.exe", ["flutter"], {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"],
      })
        .trim()
        .split(/\r?\n/)[0];
      bin = dirname(flutterCommand);
    } catch {
      const packages = JSON.parse(
        await readFile(
          resolve(flutterDir, ".dart_tool/package_config.json"),
          "utf8",
        ),
      ).packages;
      const flutterPackage = packages.find((p) => p.name === "flutter");
      if (!flutterPackage?.rootUri.startsWith("file:"))
        throw new Error("Adicione o Flutter ao PATH para compilar.");
      bin = resolve(fileURLToPath(flutterPackage.rootUri), "../../bin");
    }
    execFileSync(
      resolve(bin, "cache/dart-sdk/bin/dart.exe"),
      [
        resolve(bin, "cache/flutter_tools.snapshot"),
        "build",
        "web",
        "--release",
      ],
      { cwd: flutterDir, stdio: "inherit" },
    );
  } else {
    execFileSync("flutter", ["build", "web", "--release"], {
      cwd: flutterDir,
      stdio: "inherit",
    });
  }
}
if (
  !target.startsWith(workerDir + sep) ||
  target !== resolve(workerDir, "public")
)
  throw new Error("Pasta de saída inválida.");
await rm(target, { recursive: true, force: true });
await mkdir(target, { recursive: true });
await cp(source, target, { recursive: true });
