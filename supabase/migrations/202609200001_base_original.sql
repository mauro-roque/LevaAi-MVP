-- Base aditiva do modelo enviado. Preserva tabelas e dados existentes.
SET search_path TO public;
-- =====================================================================
-- PI — Plataforma de Fretes e Mudanças
-- Script de criação do banco de dados relacional (PostgreSQL / Supabase)
-- =====================================================================

-- Extensão para geração de UUIDs
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================================
-- ENUMS (tipos customizados)
-- =====================================================================

DO $$ BEGIN CREATE TYPE tipo_usuario AS ENUM ('cliente', 'prestador'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE tipo_endereco AS ENUM ('origem', 'destino', 'residencial', 'outro'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE status_disponibilidade AS ENUM ('disponivel', 'indisponivel'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE tipo_veiculo AS ENUM (
    'motocicleta', 'utilitario', 'fiorino', 'saveiro', 'strada',
    'van', 'caminhao_3_4', 'vuc', 'outros'
); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE status_veiculo AS ENUM ('ativo', 'inativo', 'em_manutencao'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE tipo_servico_solicitacao AS ENUM ('mudanca', 'frete'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE status_solicitacao AS ENUM (
    'criada',
    'aguardando_prestador',
    'prestador_selecionado',
    'pagamento_pendente',
    'pagamento_aprovado',
    'agendado',
    'a_caminho',
    'em_andamento',
    'concluido',
    'avaliado',
    'cancelado_cliente',
    'recusado_prestador',
    'cancelado_prestador',
    'pagamento_recusado'
); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE status_orcamento AS ENUM ('pendente', 'aceito', 'recusado', 'expirado'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE metodo_pagamento AS ENUM ('pix', 'cartao_credito', 'cartao_debito'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE status_pagamento AS ENUM ('pendente', 'aprovado', 'recusado', 'cancelado', 'reembolsado'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE tipo_notificacao AS ENUM ('status_solicitacao', 'pagamento', 'avaliacao', 'sistema'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- =====================================================================
-- USUÁRIOS (tabela base — cliente e prestador herdam daqui)
-- =====================================================================

CREATE TABLE IF NOT EXISTS usuarios (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo            tipo_usuario NOT NULL,
    nome            VARCHAR(150) NOT NULL,
    email           VARCHAR(150) NOT NULL UNIQUE,
    senha_hash      VARCHAR(255) NOT NULL,
    telefone        VARCHAR(20),
    foto_perfil_url TEXT,
    ativo           BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT now(),
    atualizado_em   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_usuarios_email ON usuarios(email);
CREATE INDEX IF NOT EXISTS idx_usuarios_tipo ON usuarios(tipo);

-- =====================================================================
-- CLIENTES (extensão de usuarios)
-- =====================================================================

CREATE TABLE IF NOT EXISTS clientes (
    usuario_id UUID PRIMARY KEY REFERENCES usuarios(id) ON DELETE CASCADE,
    cpf        VARCHAR(14) UNIQUE
);

-- =====================================================================
-- PRESTADORES (extensão de usuarios)
-- =====================================================================

CREATE TABLE IF NOT EXISTS prestadores (
    usuario_id             UUID PRIMARY KEY REFERENCES usuarios(id) ON DELETE CASCADE,
    cpf_cnpj               VARCHAR(18) UNIQUE,
    regiao_atendimento     VARCHAR(150),
    status_disponibilidade status_disponibilidade NOT NULL DEFAULT 'indisponivel',
    avaliacao_media        NUMERIC(3,2) NOT NULL DEFAULT 0,
    total_avaliacoes       INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_prestadores_disponibilidade ON prestadores(status_disponibilidade);

-- =====================================================================
-- ENDEREÇOS
-- =====================================================================

CREATE TABLE IF NOT EXISTS enderecos (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id    UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    tipo          tipo_endereco NOT NULL,
    logradouro    VARCHAR(200) NOT NULL,
    numero        VARCHAR(20),
    complemento   VARCHAR(100),
    bairro        VARCHAR(100),
    cidade        VARCHAR(100) NOT NULL,
    estado        CHAR(2) NOT NULL,
    cep           VARCHAR(9),
    latitude      NUMERIC(10,7),
    longitude     NUMERIC(10,7),
    criado_em     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_enderecos_usuario ON enderecos(usuario_id);
CREATE INDEX IF NOT EXISTS idx_enderecos_geo ON enderecos(latitude, longitude);

-- =====================================================================
-- VEÍCULOS (um prestador pode ter vários)
-- =====================================================================

CREATE TABLE IF NOT EXISTS veiculos (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prestador_id          UUID NOT NULL REFERENCES prestadores(usuario_id) ON DELETE CASCADE,
    tipo_veiculo          tipo_veiculo NOT NULL,
    marca                 VARCHAR(80),
    modelo                VARCHAR(80),
    ano                   SMALLINT,
    capacidade_carga_kg   NUMERIC(10,2),
    comprimento_m         NUMERIC(6,2),
    largura_m             NUMERIC(6,2),
    altura_m              NUMERIC(6,2),
    valor_por_km          NUMERIC(10,2) NOT NULL,
    status                status_veiculo NOT NULL DEFAULT 'ativo',
    regiao_atendimento    VARCHAR(150),
    criado_em             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_veiculos_prestador ON veiculos(prestador_id);
CREATE INDEX IF NOT EXISTS idx_veiculos_tipo ON veiculos(tipo_veiculo);
CREATE INDEX IF NOT EXISTS idx_veiculos_status ON veiculos(status);

-- =====================================================================
-- AJUDANTES (oferta de ajudantes por prestador)
-- =====================================================================

CREATE TABLE IF NOT EXISTS ajudantes (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prestador_id            UUID NOT NULL REFERENCES prestadores(usuario_id) ON DELETE CASCADE,
    quantidade_disponivel   SMALLINT NOT NULL DEFAULT 0,
    valor_por_ajudante      NUMERIC(10,2) NOT NULL,
    disponivel              BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_ajudantes_prestador ON ajudantes(prestador_id);

-- =====================================================================
-- SOLICITAÇÕES (pedido do cliente)
-- =====================================================================

CREATE TABLE IF NOT EXISTS solicitacoes (
    id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id             UUID NOT NULL REFERENCES clientes(usuario_id) ON DELETE CASCADE,
    endereco_origem_id     UUID NOT NULL REFERENCES enderecos(id),
    endereco_destino_id    UUID NOT NULL REFERENCES enderecos(id),
    data_desejada          DATE NOT NULL,
    tipo_servico           tipo_servico_solicitacao NOT NULL,
    volume_estimado_m3     NUMERIC(8,2),
    necessita_ajudantes    BOOLEAN NOT NULL DEFAULT FALSE,
    quantidade_ajudantes   SMALLINT DEFAULT 0,
    distancia_km           NUMERIC(8,2),
    rota_geojson           JSONB,
    status                 status_solicitacao NOT NULL DEFAULT 'criada',
    criado_em              TIMESTAMPTZ NOT NULL DEFAULT now(),
    atualizado_em          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_solicitacoes_cliente ON solicitacoes(cliente_id);
CREATE INDEX IF NOT EXISTS idx_solicitacoes_status ON solicitacoes(status);
CREATE INDEX IF NOT EXISTS idx_solicitacoes_data ON solicitacoes(data_desejada);

-- =====================================================================
-- ITENS DA MUDANÇA
-- =====================================================================

CREATE TABLE IF NOT EXISTS itens_mudanca (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    solicitacao_id  UUID NOT NULL REFERENCES solicitacoes(id) ON DELETE CASCADE,
    descricao       VARCHAR(150) NOT NULL,
    quantidade      SMALLINT NOT NULL DEFAULT 1,
    volume_m3       NUMERIC(8,2)
);

CREATE INDEX IF NOT EXISTS idx_itens_solicitacao ON itens_mudanca(solicitacao_id);

-- =====================================================================
-- ORÇAMENTOS (proposta de cada prestador para uma solicitação)
-- =====================================================================

CREATE TABLE IF NOT EXISTS orcamentos (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    solicitacao_id    UUID NOT NULL REFERENCES solicitacoes(id) ON DELETE CASCADE,
    prestador_id      UUID NOT NULL REFERENCES prestadores(usuario_id),
    veiculo_id        UUID NOT NULL REFERENCES veiculos(id),
    ajudantes_id      UUID REFERENCES ajudantes(id),
    quantidade_ajudantes_cotada SMALLINT DEFAULT 0,
    valor_transporte  NUMERIC(10,2) NOT NULL,
    valor_ajudantes   NUMERIC(10,2) NOT NULL DEFAULT 0,
    valor_total       NUMERIC(10,2) NOT NULL,
    tempo_estimado_min INTEGER,
    status            status_orcamento NOT NULL DEFAULT 'pendente',
    criado_em         TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (solicitacao_id, prestador_id, veiculo_id)
);

CREATE INDEX IF NOT EXISTS idx_orcamentos_solicitacao ON orcamentos(solicitacao_id);
CREATE INDEX IF NOT EXISTS idx_orcamentos_prestador ON orcamentos(prestador_id);
CREATE INDEX IF NOT EXISTS idx_orcamentos_status ON orcamentos(status);

-- =====================================================================
-- SERVIÇOS (orçamento aceito → serviço confirmado/em execução)
-- =====================================================================

CREATE TABLE IF NOT EXISTS servicos (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    solicitacao_id    UUID NOT NULL REFERENCES solicitacoes(id),
    orcamento_id      UUID NOT NULL UNIQUE REFERENCES orcamentos(id),
    prestador_id      UUID NOT NULL REFERENCES prestadores(usuario_id),
    veiculo_id        UUID NOT NULL REFERENCES veiculos(id),
    data_inicio       TIMESTAMPTZ,
    data_conclusao    TIMESTAMPTZ,
    status            status_solicitacao NOT NULL DEFAULT 'agendado',
    criado_em         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_servicos_solicitacao ON servicos(solicitacao_id);
CREATE INDEX IF NOT EXISTS idx_servicos_prestador ON servicos(prestador_id);
CREATE INDEX IF NOT EXISTS idx_servicos_status ON servicos(status);

-- =====================================================================
-- PAGAMENTOS
-- =====================================================================

CREATE TABLE IF NOT EXISTS pagamentos (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    servico_id            UUID NOT NULL REFERENCES servicos(id) ON DELETE CASCADE,
    metodo                metodo_pagamento NOT NULL,
    valor                 NUMERIC(10,2) NOT NULL,
    status                status_pagamento NOT NULL DEFAULT 'pendente',
    gateway               VARCHAR(50),
    gateway_transacao_id  VARCHAR(150),
    criado_em             TIMESTAMPTZ NOT NULL DEFAULT now(),
    atualizado_em         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pagamentos_servico ON pagamentos(servico_id);
CREATE INDEX IF NOT EXISTS idx_pagamentos_status ON pagamentos(status);

-- =====================================================================
-- AVALIAÇÕES
-- =====================================================================

CREATE TABLE IF NOT EXISTS avaliacoes (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    servico_id    UUID NOT NULL UNIQUE REFERENCES servicos(id) ON DELETE CASCADE,
    cliente_id    UUID NOT NULL REFERENCES clientes(usuario_id),
    prestador_id  UUID NOT NULL REFERENCES prestadores(usuario_id),
    nota          SMALLINT NOT NULL CHECK (nota BETWEEN 1 AND 5),
    comentario    TEXT,
    criado_em     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_avaliacoes_prestador ON avaliacoes(prestador_id);

-- =====================================================================
-- NOTIFICAÇÕES
-- =====================================================================

CREATE TABLE IF NOT EXISTS notificacoes (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id  UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    tipo        tipo_notificacao NOT NULL,
    titulo      VARCHAR(150),
    mensagem    TEXT NOT NULL,
    lida        BOOLEAN NOT NULL DEFAULT FALSE,
    criado_em   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notificacoes_usuario ON notificacoes(usuario_id, lida);

-- =====================================================================
-- HISTÓRICO DE STATUS (auditoria do fluxo da solicitação/serviço)
-- =====================================================================

CREATE TABLE IF NOT EXISTS historico_status (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    solicitacao_id  UUID REFERENCES solicitacoes(id) ON DELETE CASCADE,
    servico_id      UUID REFERENCES servicos(id) ON DELETE CASCADE,
    status_anterior VARCHAR(50),
    status_novo     VARCHAR(50) NOT NULL,
    alterado_por    UUID REFERENCES usuarios(id),
    alterado_em     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (solicitacao_id IS NOT NULL OR servico_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_historico_solicitacao ON historico_status(solicitacao_id);
CREATE INDEX IF NOT EXISTS idx_historico_servico ON historico_status(servico_id);

-- =====================================================================
-- TRIGGER: atualizar avaliacao_media do prestador automaticamente
-- =====================================================================

CREATE OR REPLACE FUNCTION atualizar_avaliacao_media()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE prestadores
    SET avaliacao_media = (
            SELECT ROUND(AVG(nota)::numeric, 2)
            FROM avaliacoes
            WHERE prestador_id = NEW.prestador_id
        ),
        total_avaliacoes = (
            SELECT COUNT(*) FROM avaliacoes WHERE prestador_id = NEW.prestador_id
        )
    WHERE usuario_id = NEW.prestador_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_atualizar_avaliacao_media
AFTER INSERT ON avaliacoes
FOR EACH ROW EXECUTE FUNCTION atualizar_avaliacao_media();

