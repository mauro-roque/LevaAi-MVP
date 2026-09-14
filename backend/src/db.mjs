import { readFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';

export async function openDatabase({ url, file = resolve('data/leva-ai.sqlite') } = {}) {
  let query, close;
  if (url) {
    const { Client } = await import('pg');
    const client = new Client({ connectionString: url });
    await client.connect();
    await client.query('CREATE SCHEMA IF NOT EXISTS leva_ai_mvp');
    await client.query('SET search_path TO leva_ai_mvp');
    query = async (sql, args = []) => (await client.query(sql, args)).rows;
    close = () => client.end();
  } else {
    const { DatabaseSync } = await import('node:sqlite');
    if (file !== ':memory:') await mkdir(dirname(file), { recursive: true });
    const sqlite = new DatabaseSync(file);
    sqlite.exec('PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL;');
    query = async (sql, args = []) => {
      const statement = sqlite.prepare(sql.replace(/\$\d+/g, '?'));
      if (/^\s*(SELECT|WITH)/i.test(sql) || /RETURNING/i.test(sql)) return statement.all(...args);
      statement.run(...args);
      return [];
    };
    close = () => sqlite.close();
  }
  const schema = await readFile(new URL('../migrations/001_mvp.sql', import.meta.url), 'utf8');
  for (const sql of schema.replace(/--[^\n]*/g, '').split(';').filter(s => s.trim())) await query(sql);
  // Uma conexão, uma fila: transações nunca se sobrepõem, inclusive no PostgreSQL.
  let tail = Promise.resolve();
  return {
    query, close,
    transaction(work) {
      const result = tail.then(async () => {
        await query('BEGIN');
        try { const value = await work(); await query('COMMIT'); return value; }
        catch (error) { await query('ROLLBACK'); throw error; }
      });
      tail = result.catch(() => {});
      return result;
    },
  };
}
