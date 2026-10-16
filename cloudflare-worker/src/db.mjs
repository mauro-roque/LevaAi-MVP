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
    /** Executa SQL parametrizado e retorna apenas as linhas do resultado. */
    async query(sql, params = []) {
      return (await client.query(sql, params)).rows;
    },
    /** Executa a operação de negócio de forma atômica com rollback em falha. */
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
    // O Hyperdrive controla o pool e o ciclo de vida do socket. Encerrar o
    // cliente explicitamente no fim da requisição pode falhar no runtime dos
    // Workers depois de a resposta já estar pronta.
    async close() {},
  };
}
