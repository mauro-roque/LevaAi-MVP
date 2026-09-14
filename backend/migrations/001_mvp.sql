-- Migração aditiva. O adaptador PostgreSQL aplica no schema isolado leva_ai_mvp.
-- Não executa ou altera o script destrutivo presente em BANCO.
CREATE TABLE IF NOT EXISTS users (
 id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT NOT NULL UNIQUE,
 password_hash TEXT NOT NULL, role TEXT NOT NULL CHECK(role IN ('cliente','prestador')),
 phone TEXT NOT NULL, available INTEGER NOT NULL DEFAULT 1 CHECK(available IN (0,1)),
 created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS sessions (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id), expires_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS vehicles (
 id TEXT PRIMARY KEY, provider_id TEXT NOT NULL REFERENCES users(id),
 active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)), data TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS vehicles_provider ON vehicles(provider_id);
CREATE TABLE IF NOT EXISTS quotes (
 id TEXT PRIMARY KEY, client_id TEXT NOT NULL REFERENCES users(id),
 vehicle_id TEXT NOT NULL REFERENCES vehicles(id), expires_at TEXT NOT NULL, data TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS bookings (
 id TEXT PRIMARY KEY, quote_id TEXT NOT NULL UNIQUE REFERENCES quotes(id),
 client_id TEXT NOT NULL REFERENCES users(id), provider_id TEXT NOT NULL REFERENCES users(id),
 vehicle_id TEXT NOT NULL REFERENCES vehicles(id), service_date TEXT NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('aguardando_prestador','pagamento_pendente','agendado','a_caminho','em_andamento','concluido','avaliado','cancelado_cliente','recusado_prestador','pagamento_recusado')),
 data TEXT NOT NULL, created_at TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS vehicle_reserved_day ON bookings(vehicle_id, service_date)
 WHERE status IN ('aguardando_prestador','pagamento_pendente','agendado','a_caminho','em_andamento');
CREATE INDEX IF NOT EXISTS bookings_client ON bookings(client_id);
CREATE INDEX IF NOT EXISTS bookings_provider ON bookings(provider_id);
CREATE TABLE IF NOT EXISTS payments (
 id TEXT PRIMARY KEY, booking_id TEXT NOT NULL UNIQUE REFERENCES bookings(id),
 amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
 status TEXT NOT NULL CHECK(status IN ('pendente','aprovado','recusado','cancelado')),
 gateway TEXT NOT NULL, external_id TEXT, data TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS reviews (
 id TEXT PRIMARY KEY, booking_id TEXT NOT NULL UNIQUE REFERENCES bookings(id),
 client_id TEXT NOT NULL REFERENCES users(id), provider_id TEXT NOT NULL REFERENCES users(id),
 rating INTEGER NOT NULL CHECK(rating BETWEEN 1 AND 5), comment TEXT NOT NULL, created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS reviews_provider ON reviews(provider_id);
CREATE TABLE IF NOT EXISTS history (
 id TEXT PRIMARY KEY, booking_id TEXT NOT NULL REFERENCES bookings(id),
 actor_id TEXT NOT NULL REFERENCES users(id), status TEXT NOT NULL, created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS history_booking ON history(booking_id);
