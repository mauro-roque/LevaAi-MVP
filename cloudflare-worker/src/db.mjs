import { Client } from "pg";
import { AppError, ensure } from "./validation.mjs";

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
    // Libera o cliente ao fim da requisição; o Hyperdrive mantém o pool da
    // conexão de origem e não precisa que o socket do Worker fique aberto.
    async close() {
      await client.end();
    },
  };
}
