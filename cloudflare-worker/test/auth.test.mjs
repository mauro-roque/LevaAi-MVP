import test from "node:test";
import assert from "node:assert/strict";
import {
  hashPassword,
  verifyPassword,
  signToken,
  verifyToken,
} from "../src/auth.mjs";

test("senha PBKDF2 e JWT do Worker são verificados sem expor segredo", async () => {
  const secret = "uma-chave-de-teste-com-mais-de-trinta-e-dois-caracteres";
  const hash = await hashPassword("SenhaSegura@123");
  assert.equal(await verifyPassword("SenhaSegura@123", hash), true);
  assert.equal(await verifyPassword("outra-senha", hash), false);
  const token = await signToken({ id: "cliente-1" }, secret, "sessao-1");
  assert.equal((await verifyToken(token, secret)).sub, "cliente-1");
  assert.equal(
    await verifyToken(token, "segredo-errado-com-mais-de-32-caracteres"),
    null,
  );
});
