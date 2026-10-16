-- Confirmação de e-mail para contas criadas pela API do LevaAí.
BEGIN;
ALTER TABLE public.usuarios
  ADD COLUMN IF NOT EXISTS email_verificado boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS leva_ai_private.verificacoes_email (
  token_hash text PRIMARY KEY,
  usuario_id uuid NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  expira_em timestamptz NOT NULL,
  criado_em timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS verificacoes_email_usuario_idx
  ON leva_ai_private.verificacoes_email(usuario_id);
COMMIT;
