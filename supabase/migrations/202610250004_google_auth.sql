-- Vincula uma conta local à identidade imutável devolvida pelo Google.
-- O e-mail pode mudar; o campo `sub` do Google é o identificador seguro.
ALTER TABLE public.usuarios
  ADD COLUMN IF NOT EXISTS google_sub TEXT UNIQUE;
