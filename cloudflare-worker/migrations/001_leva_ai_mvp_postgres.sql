-- Execute uma vez no SQL Editor do Supabase, com uma conta administrativa.
-- É aditivo e usa schema isolado; não apaga nem altera o schema public existente.
CREATE SCHEMA IF NOT EXISTS leva_ai_mvp;
SET search_path TO leva_ai_mvp;

CREATE TABLE IF NOT EXISTS users (
 id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT NOT NULL UNIQUE,
 password_hash TEXT NOT NULL, role TEXT NOT NULL CHECK(role IN ('cliente','prestador')),
 phone TEXT NOT NULL, available BOOLEAN NOT NULL DEFAULT TRUE, created_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE IF NOT EXISTS sessions (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id), expires_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE IF NOT EXISTS vehicles (
 id TEXT PRIMARY KEY, provider_id TEXT NOT NULL REFERENCES users(id), active BOOLEAN NOT NULL DEFAULT TRUE,
 data JSONB NOT NULL
);
CREATE INDEX IF NOT EXISTS vehicles_provider ON vehicles(provider_id);
CREATE TABLE IF NOT EXISTS quotes (
 id TEXT PRIMARY KEY, client_id TEXT NOT NULL REFERENCES users(id), vehicle_id TEXT NOT NULL REFERENCES vehicles(id),
 expires_at TIMESTAMPTZ NOT NULL, data JSONB NOT NULL
);
CREATE TABLE IF NOT EXISTS bookings (
 id TEXT PRIMARY KEY, quote_id TEXT NOT NULL UNIQUE REFERENCES quotes(id), client_id TEXT NOT NULL REFERENCES users(id),
 provider_id TEXT NOT NULL REFERENCES users(id), vehicle_id TEXT NOT NULL REFERENCES vehicles(id), service_date DATE NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('aguardando_prestador','pagamento_pendente','agendado','a_caminho','em_andamento','concluido','avaliado','cancelado_cliente','recusado_prestador','pagamento_recusado')),
 data JSONB NOT NULL, created_at TIMESTAMPTZ NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS vehicle_reserved_day ON bookings(vehicle_id, service_date)
 WHERE status IN ('aguardando_prestador','pagamento_pendente','agendado','a_caminho','em_andamento');
CREATE INDEX IF NOT EXISTS bookings_client ON bookings(client_id);
CREATE INDEX IF NOT EXISTS bookings_provider ON bookings(provider_id);
CREATE TABLE IF NOT EXISTS payments (
 id TEXT PRIMARY KEY, booking_id TEXT NOT NULL UNIQUE REFERENCES bookings(id), amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
 status TEXT NOT NULL CHECK(status IN ('pendente','aprovado','recusado','cancelado')), gateway TEXT NOT NULL, external_id TEXT, data JSONB NOT NULL
);
CREATE TABLE IF NOT EXISTS reviews (
 id TEXT PRIMARY KEY, booking_id TEXT NOT NULL UNIQUE REFERENCES bookings(id), client_id TEXT NOT NULL REFERENCES users(id),
 provider_id TEXT NOT NULL REFERENCES users(id), rating SMALLINT NOT NULL CHECK(rating BETWEEN 1 AND 5), comment TEXT NOT NULL, created_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS reviews_provider ON reviews(provider_id);
CREATE TABLE IF NOT EXISTS history (
 id TEXT PRIMARY KEY, booking_id TEXT NOT NULL REFERENCES bookings(id), actor_id TEXT NOT NULL REFERENCES users(id),
 status TEXT NOT NULL, created_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS history_booking ON history(booking_id);

REVOKE ALL ON SCHEMA leva_ai_mvp FROM anon, authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA leva_ai_mvp FROM anon, authenticated;
