import {
  randomBytes,
  scrypt,
  timingSafeEqual,
  createHmac,
  randomUUID,
} from "node:crypto";
import { promisify } from "node:util";
const derive = promisify(scrypt);
/** Gera um hash de senha adequado para armazenamento no backend local. */
export async function hashPassword(password) {
  const salt = randomBytes(16).toString("hex");
  return `${salt}:${(await derive(password, salt, 64)).toString("hex")}`;
}
/** Confere uma senha recebida contra o hash persistido. */
export async function verifyPassword(password, hash) {
  const [salt, expected] = hash.split(":");
  return timingSafeEqual(
    await derive(password, salt, 64),
    Buffer.from(expected, "hex"),
  );
}
/** Assina a sessão JWT usada pelas rotas autenticadas. */
export function signToken(user, secret, sessionId) {
  const header = Buffer.from(
    JSON.stringify({ alg: "HS256", typ: "JWT" }),
  ).toString("base64url");
  const payload = Buffer.from(
    JSON.stringify({
      sub: user.id,
      jti: sessionId,
      iss: "leva-ai",
      aud: "leva-ai-app",
      exp: Math.floor(Date.now() / 1000) + 28800,
    }),
  ).toString("base64url");
  const unsigned = `${header}.${payload}`;
  return `${unsigned}.${createHmac("sha256", secret).update(unsigned).digest("base64url")}`;
}
/** Valida um token recebido antes de recuperar o usuário. */
export function verifyToken(token, secret) {
  try {
    const [header, payload, signature, extra] = token.split(".");
    if (extra || JSON.parse(Buffer.from(header, "base64url")).alg !== "HS256")
      return null;
    const expected = createHmac("sha256", secret)
      .update(`${header}.${payload}`)
      .digest();
    const actual = Buffer.from(signature, "base64url");
    if (actual.length !== expected.length || !timingSafeEqual(actual, expected))
      return null;
    const claims = JSON.parse(Buffer.from(payload, "base64url"));
    if (
      claims.iss !== "leva-ai" ||
      claims.aud !== "leva-ai-app" ||
      claims.exp <= Date.now() / 1000
    )
      return null;
    return claims;
  } catch {
    return null;
  }
}
export const id = () => randomUUID();
export const publicUser = ({ id, name, email, role, phone, available }) => ({
  id,
  name,
  email,
  role,
  phone,
  available: !!available,
});
