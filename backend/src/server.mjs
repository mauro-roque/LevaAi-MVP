import { openDatabase } from './db.mjs';
import { configuration, createApp, seed } from './app.mjs';
const config = configuration();
const db = await openDatabase({ url: process.env.DATABASE_URL });
if (config.demo) await seed(db);
const server = createApp(db, config);
const host = process.env.HOST || '0.0.0.0', port = Number(process.env.PORT || 3000);
server.listen(port, host, () => console.log(`LevaAí: http://${host}:${port} | ${config.demo ? 'DEMONSTRAÇÃO — Pix simulado' : 'Integrações reais'}`));
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close(async () => { await db.close(); process.exit(0); }));
