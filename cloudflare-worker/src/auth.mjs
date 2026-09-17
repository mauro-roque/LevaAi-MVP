import { AppError, ensure } from "./validation.mjs";

/** Utilitários de autenticação compatíveis com o Web Crypto do Cloudflare. */
const encoder = new TextEncoder();
const toBase64 = (value) =>
  btoa(String.fromCharCode(...new Uint8Array(value)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
const fromBase64 = (value) =>
  Uint8Array.from(
    atob(
      value
        .replace(/-/g, "+")
        .replace(/_/g, "/")
        .padEnd(Math.ceil(value.length / 4) * 4, "="),
    ),
    (char) => char.charCodeAt(0),
  );
// Workers aceita no máximo 100 mil iterações no PBKDF2 via Web Crypto.
async function derive(password, salt, iterations = 100000) {
  const source = await crypto.subtle.importKey(
    "raw",
    encoder.encode(password),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  return new Uint8Array(
    await crypto.subtle.deriveBits(
      { name: "PBKDF2", hash: "SHA-256", salt, iterations },
      source,
      256,
    ),
  );
}
function safeEqual(a, b) {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) result |= a[i] ^ b[i];
  return result === 0;
}
/** Gera identificadores imprevisíveis para entidades persistidas. */
export const id = () => crypto.randomUUID();
/** Cria um hash PBKDF2 serializável para armazenar uma senha. */
export async function hashPassword(password) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  return `pbkdf2:100000:${toBase64(salt)}:${toBase64(await derive(password, salt))}`;
}
/** Confere uma senha sem expor detalhes do hash ou da falha. */
export async function verifyPassword(password, stored) {
  try {
    const [type, count, salt, expected] = stored.split(":");
    if (type !== "pbkdf2") return false;
    return safeEqual(
      await derive(password, fromBase64(salt), Number(count)),
      fromBase64(expected),
    );
  } catch {
    return false;
  }
}
async function sign(unsigned, secret) {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return toBase64(
    await crypto.subtle.sign("HMAC", key, encoder.encode(unsigned)),
  );
}
/** Assina o token de sessão usado pelo aplicativo autenticado. */
export async function signToken(user, secret, sessionId) {
  const header = toBase64(
      encoder.encode(JSON.stringify({ alg: "HS256", typ: "JWT" })),
    ),
    payload = toBase64(
      encoder.encode(
        JSON.stringify({
          sub: user.id,
          jti: sessionId,
          iss: "leva-ai",
          aud: "leva-ai-app",
          exp: Math.floor(Date.now() / 1000) + 28800,
        }),
      ),
    ),
    unsigned = `${header}.${payload}`;
  return `${unsigned}.${await sign(unsigned, secret)}`;
}
/** Valida o token de sessão antes de liberar uma rota protegida. */
export async function verifyToken(token, secret) {
  try {
    const [header, payload, signature, extra] = token.split(".");
    if (
      extra ||
      JSON.parse(new TextDecoder().decode(fromBase64(header))).alg !==
        "HS256" ||
      !safeEqual(
        fromBase64(signature),
        fromBase64(await sign(`${header}.${payload}`, secret)),
      )
    )
      return null;
    const claims = JSON.parse(new TextDecoder().decode(fromBase64(payload)));
    return claims.iss === "leva-ai" &&
      claims.aud === "leva-ai-app" &&
      claims.exp > Date.now() / 1000
      ? claims
      : null;
  } catch {
    return null;
  }
}
/** Remove campos privados antes de devolver um usuário ao cliente. */
export function publicUser(user) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    role: user.role,
    phone: user.phone,
    available: !!user.available,
  };
}
/** Impede que o Worker opere sem a chave das sessões. */
export function requireSecret(secret) {
  ensure(
    typeof secret === "string" && secret.length >= 32,
    "JWT_SECRET precisa ter ao menos 32 caracteres.",
    500,
  );
}
