import { Client } from "pg";
import { AppError, ensure } from "./validation.mjs";

/** Abre PostgreSQL pelo Hyperdrive e fixa o schema isolado do MVP. */
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
    await client.query("SET search_path TO leva_ai_mvp");
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
