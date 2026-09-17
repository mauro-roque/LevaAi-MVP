import { Client } from "pg";
import { AppError, ensure } from "./validation.mjs";

/** Move a estrutura inicial ao schema padrão, que é estável com o Hyperdrive. */
async function normalizeMvpSchema(client) {
  await client.query(`
    DO $$
    BEGIN
      IF to_regclass('leva_ai_mvp.users') IS NOT NULL THEN
        ALTER TABLE leva_ai_mvp.history SET SCHEMA public;
        ALTER TABLE leva_ai_mvp.reviews SET SCHEMA public;
        ALTER TABLE leva_ai_mvp.payments SET SCHEMA public;
        ALTER TABLE leva_ai_mvp.bookings SET SCHEMA public;
        ALTER TABLE leva_ai_mvp.quotes SET SCHEMA public;
        ALTER TABLE leva_ai_mvp.vehicles SET SCHEMA public;
        ALTER TABLE leva_ai_mvp.sessions SET SCHEMA public;
        ALTER TABLE leva_ai_mvp.users SET SCHEMA public;
      END IF;
    END $$;
  `);
}

/** Abre PostgreSQL pelo Hyperdrive para as rotas do MVP. */
export async function openDatabase(env) {
  ensure(
    env.HYPERDRIVE?.connectionString,
    "A vinculação Hyperdrive não está configurada.",
    503,
  );
  const client = new Client({
    connectionString: env.HYPERDRIVE.connectionString,
    connectionTimeoutMillis: 8000,
  });
  try {
    await client.connect();
    await normalizeMvpSchema(client);
  } catch (error) {
    try {
      await client.end();
    } catch {}
    throw new AppError("Não foi possível acessar o banco de dados.", 503);
  }
  return {
    async query(sql, params = []) {
      return (await client.query(sql, params)).rows;
    },
    async transaction(work) {
      await client.query("BEGIN");
      try {
        const value = await work();
        await client.query("COMMIT");
        return value;
      } catch (error) {
        await client.query("ROLLBACK");
        throw error;
      }
    },
    // O Hyperdrive administra o pool do PostgreSQL. Não encerrar o cliente
    // manualmente evita que a resposta HTTP aguarde o desligamento do socket.
    close() {},
  };
}
