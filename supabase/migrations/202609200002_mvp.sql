-- Extensões aditivas. As entidades de negócio continuam no modelo original.
BEGIN;
CREATE SCHEMA IF NOT EXISTS leva_ai_private;
ALTER TABLE public.veiculos ADD COLUMN IF NOT EXISTS volume_m3 numeric(8,2);
ALTER TABLE public.veiculos ADD COLUMN IF NOT EXISTS base_endereco jsonb;
ALTER TABLE public.veiculos ADD COLUMN IF NOT EXISTS raio_km numeric(8,2) DEFAULT 60;
ALTER TABLE public.veiculos ADD COLUMN IF NOT EXISTS ajudantes_id uuid REFERENCES public.ajudantes(id);
ALTER TABLE public.solicitacoes ADD COLUMN IF NOT EXISTS peso_kg numeric(10,2);
ALTER TABLE public.solicitacoes ADD COLUMN IF NOT EXISTS detalhes jsonb NOT NULL DEFAULT '{}';
ALTER TABLE public.orcamentos ADD COLUMN IF NOT EXISTS detalhes jsonb NOT NULL DEFAULT '{}';
ALTER TABLE public.orcamentos ADD COLUMN IF NOT EXISTS cotacao_chave uuid;
ALTER TABLE public.pagamentos ADD COLUMN IF NOT EXISTS detalhes jsonb NOT NULL DEFAULT '{}';
CREATE UNIQUE INDEX IF NOT EXISTS orcamento_cotacao_chave ON public.orcamentos(cotacao_chave);
CREATE UNIQUE INDEX IF NOT EXISTS servico_unico_solicitacao ON public.servicos(solicitacao_id);
CREATE UNIQUE INDEX IF NOT EXISTS pagamento_unico_servico ON public.pagamentos(servico_id);
CREATE TABLE IF NOT EXISTS leva_ai_private.sessoes (
 id uuid PRIMARY KEY, usuario_id uuid NOT NULL REFERENCES public.usuarios(id), expira_em timestamptz NOT NULL
);
CREATE TABLE IF NOT EXISTS leva_ai_private.cotacoes (
 id uuid PRIMARY KEY, cliente_id uuid NOT NULL REFERENCES public.clientes(usuario_id),
 veiculo_id uuid NOT NULL REFERENCES public.veiculos(id), expira_em timestamptz NOT NULL, dados jsonb NOT NULL
);
CREATE TABLE IF NOT EXISTS leva_ai_private.reservas (
 solicitacao_id uuid PRIMARY KEY REFERENCES public.solicitacoes(id),
 veiculo_id uuid NOT NULL REFERENCES public.veiculos(id), data date NOT NULL, UNIQUE(veiculo_id,data)
);
CREATE TABLE IF NOT EXISTS leva_ai_private.recuperacoes (
 token_hash text PRIMARY KEY, usuario_id uuid NOT NULL REFERENCES public.usuarios(id), expira_em timestamptz NOT NULL
);
CREATE TABLE IF NOT EXISTS leva_ai_private.enderecos_salvos (
 id uuid PRIMARY KEY, usuario_id uuid NOT NULL REFERENCES public.usuarios(id), nome varchar(80) NOT NULL,
 ponto jsonb NOT NULL
);
-- A API do Worker aplica autorização. O acesso direto pelo cliente é fechado.
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['usuarios','clientes','prestadores','enderecos','veiculos','ajudantes','solicitacoes','itens_mudanca','orcamentos','servicos','pagamentos','avaliacoes','notificacoes','historico_status'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
  IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN EXECUTE format('REVOKE ALL ON public.%I FROM anon',t); END IF;
  IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN EXECUTE format('REVOKE ALL ON public.%I FROM authenticated',t); END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN REVOKE ALL ON SCHEMA leva_ai_private FROM anon; END IF;
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN REVOKE ALL ON SCHEMA leva_ai_private FROM authenticated; END IF;
END $$;
COMMIT;
