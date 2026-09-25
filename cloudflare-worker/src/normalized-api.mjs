import {
  id,
  hashPassword,
  verifyPassword,
  publicUser,
  signToken,
  verifyToken,
} from "./auth.mjs";
import {
  AppError,
  ensure,
  text,
  number,
  serviceInput,
  vehicleInput,
  point,
} from "./validation.mjs";
import { createMaps, demoPlaces, distance } from "./maps.mjs";
import { createPayments } from "./payments.mjs";
export { configuration } from "./api.mjs";

/** Converte o valor numérico do banco para centavos inteiros. */
const money = (n) => Math.round(Number(n) * 100);
const active = [
  "aguardando_prestador",
  "pagamento_pendente",
  "agendado",
  "a_caminho",
  "em_andamento",
];
/** Rejeita identificadores que não tenham o formato UUID esperado. */
const uuid = (value) => {
  ensure(
    typeof value === "string" &&
      /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(value),
    "Identificador inválido.",
  );
  return value;
};
const userSql = `SELECT u.id,u.nome AS name,u.email,u.senha_hash AS password_hash,u.tipo AS role,u.telefone AS phone,u.ativo,
 coalesce(p.status_disponibilidade='disponivel',true) AS available FROM public.usuarios u LEFT JOIN public.prestadores p ON p.usuario_id=u.id`;
const vehicleSql = `SELECT v.*,a.quantidade_disponivel,a.valor_por_ajudante,a.disponivel AS equipe_disponivel
 FROM public.veiculos v LEFT JOIN public.ajudantes a ON a.id=v.ajudantes_id`;
/** Traduz a linha SQL do veículo para o contrato usado pelo aplicativo. */
function vehicleModel(v) {
  return {
    id: v.id,
    provider_id: v.prestador_id,
    active: v.status === "ativo",
    data: {
      model: [v.marca, v.modelo].filter(Boolean).join(" "),
      type: v.tipo_veiculo,
      capacityKg: Number(v.capacidade_carga_kg || 0),
      volumeM3: Number(
        v.volume_m3 ||
          Number(v.comprimento_m) * Number(v.largura_m) * Number(v.altura_m) ||
          0,
      ),
      pricePerKmCents: money(v.valor_por_km),
      helpers: v.equipe_disponivel ? Number(v.quantidade_disponivel) : 0,
      helperPriceCents: money(v.valor_por_ajudante || 0),
      base: v.base_endereco,
      radiusKm: Number(v.raio_km || 60),
      active: v.status === "ativo",
    },
  };
}
const typeMap = {
  Van: "van",
  Utilitário: "utilitario",
  "Caminhão 3/4": "caminhao_3_4",
  Fiorino: "fiorino",
  Motocicleta: "motocicleta",
};
const vehicleTypes = [
  "motocicleta",
  "utilitario",
  "fiorino",
  "saveiro",
  "strada",
  "van",
  "caminhao_3_4",
  "vuc",
  "outros",
];
/** Calcula o hash de um código temporário sem armazená-lo em texto puro. */
const digest = async (value) =>
  Array.from(
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
    ),
  )
    .map((n) => n.toString(16).padStart(2, "0"))
    .join("");

export async function seed(db) {
  // Seed explícito, transacional e serializado. Nunca rodar em ambiente real.
  if ((await db.query("SELECT id FROM public.usuarios LIMIT 1")).length) return;
  await db.query("SELECT pg_advisory_xact_lock(20260920)");
  if ((await db.query("SELECT id FROM public.usuarios LIMIT 1")).length) return;
  const hash = await hashPassword("LevaAi@123");
  const customer = id(),
    provider = id(),
    other = id();
  for (const [uid, name, email, role] of [
    [customer, "Mariana Silva", "cliente@levaai.demo", "cliente"],
    [provider, "Carlos Transportes", "prestador@levaai.demo", "prestador"],
    [other, "Mudanças Horizonte", "horizonte@levaai.demo", "prestador"],
  ]) {
    await db.query(
      "INSERT INTO public.usuarios(id,nome,email,senha_hash,tipo,telefone) VALUES($1,$2,$3,$4,$5,$6)",
      [uid, name, email, hash, role, "(11) 99999-0000"],
    );
    if (role === "cliente")
      await db.query("INSERT INTO public.clientes(usuario_id) VALUES($1)", [
        uid,
      ]);
    else
      await db.query(
        "INSERT INTO public.prestadores(usuario_id,status_disponibilidade,regiao_atendimento) VALUES($1,'disponivel','São Paulo')",
        [uid],
      );
  }
  for (const [pid, model, type, kg, volume, price, helpers, helperPrice] of [
    [provider, "Fiat Ducato", "van", 1500, 12, 4.5, 2, 80],
    [provider, "Fiat Fiorino", "fiorino", 650, 3.3, 3.5, 1, 70],
    [other, "Mercedes-Benz Accelo", "caminhao_3_4", 3000, 24, 6.5, 3, 90],
  ]) {
    const aid = id();
    await db.query(
      "INSERT INTO public.ajudantes(id,prestador_id,quantidade_disponivel,valor_por_ajudante) VALUES($1,$2,$3,$4)",
      [aid, pid, helpers, helperPrice],
    );
    await db.query(
      "INSERT INTO public.veiculos(prestador_id,tipo_veiculo,modelo,capacidade_carga_kg,volume_m3,valor_por_km,base_endereco,ajudantes_id) VALUES($1,$2,$3,$4,$5,$6,$7,$8)",
      [pid, type, model, kg, volume, price, JSON.stringify(demoPlaces[0]), aid],
    );
  }
}

export function createApi(db, config) {
  const maps = createMaps(config),
    payments = createPayments(config);
  /** Retorna a primeira linha de uma consulta ou `undefined`. */
  const one = async (sql, p = []) => (await db.query(sql, p))[0];
  /** Exige o perfil correto antes de executar uma ação do domínio. */
  const role = (u, r) =>
    ensure(u?.role === r, "Seu perfil não pode realizar esta ação.", 403);
  /** Resolve a sessão JWT em um usuário ativo do banco. */
  async function currentUser(auth) {
    const claims = await verifyToken(
      (auth || "").replace(/^Bearer /, ""),
      config.secret,
    );
    ensure(claims, "Entre na sua conta para continuar.", 401);
    const s = await one(
      "SELECT id FROM leva_ai_private.sessoes WHERE id=$1 AND usuario_id=$2 AND expira_em>now()",
      [claims.jti, claims.sub],
    );
    ensure(s, "Sua sessão expirou. Entre novamente.", 401);
    const u = await one(userSql + " WHERE u.id=$1", [claims.sub]);
    ensure(u?.ativo, "Conta indisponível.", 401);
    return { ...u, sessionId: s.id };
  }
  /** Cria uma sessão persistida e entrega o token ao cliente autenticado. */
  async function session(u) {
    const sid = id();
    await db.query(
      "INSERT INTO leva_ai_private.sessoes(id,usuario_id,expira_em) VALUES($1,$2,$3)",
      [sid, u.id, new Date(Date.now() + 28800000).toISOString()],
    );
    return {
      user: publicUser(u),
      token: await signToken(u, config.secret, sid),
    };
  }
  /** Carrega dados públicos, frota ativa e avaliações do prestador. */
  async function providerDetails(pid) {
    const p = await one(
      'SELECT u.nome AS name,u.foto_perfil_url AS photo,p.regiao_atendimento AS region,p.avaliacao_media AS rating,p.total_avaliacoes AS "reviewCount" FROM public.prestadores p JOIN public.usuarios u ON u.id=p.usuario_id WHERE u.id=$1 AND u.ativo',
      [pid],
    );
    ensure(p, "Prestador não encontrado.", 404);
    const vehicles = (
      await db.query(
        vehicleSql + " WHERE v.prestador_id=$1 AND v.status='ativo'",
        [pid],
      )
    )
      .map(vehicleModel)
      .map((v) => ({ ...v, data: { ...v.data, base: undefined } }));
    const reviews = await db.query(
      "SELECT nota AS rating,comentario AS comment,criado_em AS created_at FROM public.avaliacoes WHERE prestador_id=$1 ORDER BY criado_em DESC LIMIT 20",
      [pid],
    );
    return { ...p, rating: Number(p.rating), vehicles, reviews };
  }
  /** Verifica se veículo, equipe, distância e agenda atendem à cotação. */
  async function compatible(v, input, exclude = null) {
    const p = await one(
      "SELECT 1 FROM public.prestadores p JOIN public.usuarios u ON u.id=p.usuario_id WHERE p.usuario_id=$1 AND p.status_disponibilidade='disponivel' AND u.ativo",
      [v.provider_id],
    );
    const d = v.data;
    if (
      !p ||
      !v.active ||
      !d.base ||
      d.capacityKg < input.weightKg ||
      d.volumeM3 < input.volumeM3 ||
      d.helpers < input.helpers ||
      distance(d.base, input.origin) > d.radiusKm
    )
      return false;
    return !(await one(
      "SELECT 1 FROM leva_ai_private.reservas WHERE veiculo_id=$1 AND data=$2 AND ($3::uuid IS NULL OR solicitacao_id<>$3)",
      [v.id, input.date, exclude],
    ));
  }
  /** Monta a visão completa de uma solicitação autorizada. */
  async function details(s) {
    const o = await one(
      "SELECT * FROM public.orcamentos WHERE solicitacao_id=$1 ORDER BY criado_em LIMIT 1",
      [s.id],
    );
    ensure(o, "Orçamento indisponível.", 409);
    const service = await one(
      "SELECT * FROM public.servicos WHERE solicitacao_id=$1",
      [s.id],
    );
    const p = service
      ? await one("SELECT * FROM public.pagamentos WHERE servico_id=$1", [
          service.id,
        ])
      : null;
    const review = service
      ? await one(
          "SELECT nota AS rating,comentario AS comment FROM public.avaliacoes WHERE servico_id=$1",
          [service.id],
        )
      : null;
    const history = await db.query(
      "SELECT status_novo AS status,alterado_em AS created_at FROM public.historico_status WHERE solicitacao_id=$1 ORDER BY alterado_em,id",
      [s.id],
    );
    const client = await one(
      "SELECT nome AS name,telefone AS phone FROM public.usuarios WHERE id=$1",
      [s.cliente_id],
    );
    const provider = await one(
      "SELECT nome AS name,telefone AS phone FROM public.usuarios WHERE id=$1",
      [o.prestador_id],
    );
    return {
      id: s.id,
      client_id: s.cliente_id,
      provider_id: o.prestador_id,
      vehicle_id: o.veiculo_id,
      quote_id: o.cotacao_chave,
      service_date:
        s.data_desejada instanceof Date
          ? s.data_desejada.toISOString().slice(0, 10)
          : String(s.data_desejada).slice(0, 10),
      status: s.status,
      created_at: s.criado_em,
      data: o.detalhes,
      client,
      provider,
      review: review || null,
      history,
      payment: p
        ? {
            id: p.id,
            amount_cents: money(p.valor),
            status: p.status,
            gateway: p.gateway,
            external_id: p.gateway_transacao_id,
            data: p.detalhes,
          }
        : null,
    };
  }
  /** Busca solicitação do cliente ou prestador e opcionalmente bloqueia a linha. */
  async function bookingFor(u, bid, lock = false) {
    const s = await one(
      "SELECT * FROM public.solicitacoes WHERE id=$1" +
        (lock ? " FOR UPDATE" : ""),
      [uuid(bid)],
    );
    ensure(s, "Solicitação não encontrada.", 404);
    const o = await one(
      "SELECT prestador_id FROM public.orcamentos WHERE solicitacao_id=$1",
      [s.id],
    );
    ensure(
      [s.cliente_id, o?.prestador_id].includes(u.id),
      "Solicitação não encontrada.",
      404,
    );
    return s;
  }
  /** Persiste uma transição válida de status e registra seu histórico. */
  async function change(s, status, u) {
    await db.query(
      "UPDATE public.solicitacoes SET status=$1,atualizado_em=now() WHERE id=$2",
      [status, s.id],
    );
    await db.query(
      "UPDATE public.servicos SET status=$1::public.status_solicitacao,data_inicio=CASE WHEN $1::public.status_solicitacao='em_andamento' THEN now() ELSE data_inicio END,data_conclusao=CASE WHEN $1::public.status_solicitacao='concluido' THEN now() ELSE data_conclusao END WHERE solicitacao_id=$2",
      [status, s.id],
    );
    await db.query(
      "INSERT INTO public.historico_status(solicitacao_id,status_anterior,status_novo,alterado_por) VALUES($1,$2,$3,$4)",
      [s.id, s.status, status, u.id],
    );
    if (!active.includes(status))
      await db.query(
        "DELETE FROM leva_ai_private.reservas WHERE solicitacao_id=$1",
        [s.id],
      );
    s.status = status;
  }
  /** Cria ou atualiza veículo e equipe do prestador dentro da mesma transação. */
  async function saveVehicle(u, b, vid = null) {
    role(u, "prestador");
    const data = vehicleInput(b);
    const existing = vid
      ? await one(
          "SELECT * FROM public.veiculos WHERE id=$1 AND prestador_id=$2 FOR UPDATE",
          [uuid(vid), u.id],
        )
      : null;
    ensure(!vid || existing, "Veículo não encontrado.", 404);
    let aid = existing?.ajudantes_id;
    if (!aid) {
      aid = id();
      await db.query(
        "INSERT INTO public.ajudantes(id,prestador_id,quantidade_disponivel,valor_por_ajudante) VALUES($1,$2,$3,$4)",
        [aid, u.id, data.helpers, data.helperPriceCents / 100],
      );
    } else
      await db.query(
        "UPDATE public.ajudantes SET quantidade_disponivel=$1,valor_por_ajudante=$2 WHERE id=$3 AND prestador_id=$4",
        [data.helpers, data.helperPriceCents / 100, aid, u.id],
      );
    const t = typeMap[data.type] || data.type;
    ensure(vehicleTypes.includes(t), "Tipo de veículo inválido.");
    const params = [
      u.id,
      t,
      data.model,
      data.capacityKg,
      data.volumeM3,
      data.pricePerKmCents / 100,
      JSON.stringify(data.base),
      data.radiusKm,
      aid,
      data.active ? "ativo" : "inativo",
    ];
    if (vid)
      await db.query(
        "UPDATE public.veiculos SET tipo_veiculo=$2,marca=NULL,modelo=$3,capacidade_carga_kg=$4,volume_m3=$5,valor_por_km=$6,base_endereco=$7,raio_km=$8,ajudantes_id=$9,status=$10 WHERE prestador_id=$1 AND id=$11",
        [...params, vid],
      );
    else {
      vid = id();
      await db.query(
        "INSERT INTO public.veiculos(prestador_id,tipo_veiculo,modelo,capacidade_carga_kg,volume_m3,valor_por_km,base_endereco,raio_km,ajudantes_id,status,id) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)",
        [...params, vid],
      );
    }
    return { id: vid, provider_id: u.id, active: data.active, data };
  }
  /** Persiste um ponto geocodificado no endereço de origem ou destino do frete. */
  async function createAddress(uid, p, type) {
    const aid = id();
    await db.query(
      "INSERT INTO public.enderecos(id,usuario_id,tipo,logradouro,cidade,estado,latitude,longitude) VALUES($1,$2,$3,$4,$5,$6,$7,$8)",
      [
        aid,
        uid,
        type,
        p.label.slice(0, 200),
        p.city || "Não informada",
        p.state || "BR",
        p.lat,
        p.lon,
      ],
    );
    return aid;
  }
  return {
    /** Encaminha cada rota do contrato HTTP para a regra de negócio correspondente. */
    async handle({ method, path, url, body = {}, authorization }) {
      const guestRoutes = ["/api/quotes", "/api/maps/search"];
      const isPublic =
        (path.startsWith("/api/auth/") && path != "/api/auth/logout") ||
        /^\/api\/providers\/[^/]+$/.test(path);
      const u = isPublic
        ? null
        : guestRoutes.includes(path) && !authorization
          ? null
          : await currentUser(authorization);
      if (method === "POST" && path === "/api/auth/register") {
        const name = text(body.name, "Nome", 2, 150),
          email = text(body.email, "E-mail", 5, 150).toLowerCase(),
          password = text(body.password, "Senha", 8, 128),
          phone = text(body.phone, "Telefone", 10, 20);
        ensure(
          /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email),
          "Informe um e-mail válido.",
        );
        ensure(
          ["cliente", "prestador"].includes(body.role),
          "Escolha seu perfil.",
        );
        ensure(
          !(await one("SELECT id FROM public.usuarios WHERE lower(email)=$1", [
            email,
          ])),
          "Este e-mail já está cadastrado.",
          409,
        );
        const uid = id();
        await db.query(
          "INSERT INTO public.usuarios(id,nome,email,senha_hash,tipo,telefone) VALUES($1,$2,$3,$4,$5,$6)",
          [uid, name, email, await hashPassword(password), body.role, phone],
        );
        if (body.role === "cliente")
          await db.query("INSERT INTO public.clientes(usuario_id) VALUES($1)", [
            uid,
          ]);
        else
          await db.query(
            "INSERT INTO public.prestadores(usuario_id) VALUES($1)",
            [uid],
          );
        return session(await one(userSql + " WHERE u.id=$1", [uid]));
      }
      if (method === "POST" && path === "/api/auth/login") {
        const email = text(body.email, "E-mail", 3, 150).toLowerCase(),
          password = text(body.password, "Senha", 1, 128);
        const found = await one(userSql + " WHERE lower(u.email)=$1", [email]);
        ensure(
          found?.ativo && (await verifyPassword(password, found.password_hash)),
          "E-mail ou senha incorretos.",
          401,
        );
        return session(found);
      }
      if (method === "POST" && path === "/api/auth/forgot") {
        ensure(
          config.resendToken && config.mailFrom,
          "Recuperação por e-mail ainda não configurada.",
          503,
        );
        const email = text(body.email, "E-mail", 5, 150).toLowerCase();
        const user = await one(
          "SELECT id FROM public.usuarios WHERE lower(email)=$1 AND ativo",
          [email],
        );
        if (user) {
          const token = id() + id();
          const hashed = await digest(token);
          await db.query(
            "DELETE FROM leva_ai_private.recuperacoes WHERE usuario_id=$1",
            [user.id],
          );
          await db.query(
            "INSERT INTO leva_ai_private.recuperacoes(token_hash,usuario_id,expira_em) VALUES($1,$2,$3)",
            [hashed, user.id, new Date(Date.now() + 1800000).toISOString()],
          );
          const response = await fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: {
              Authorization: `Bearer ${config.resendToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              from: config.mailFrom,
              to: [email],
              subject: "Recuperar acesso ao LevaAí",
              text: `Use este código no aplicativo em até 30 minutos:\n\n${token}\n\nSe não solicitou, ignore esta mensagem.`,
            }),
          });
          ensure(
            response.ok,
            "Não foi possível enviar o e-mail. Tente novamente.",
            503,
          );
        }
        return {
          message:
            "Se o e-mail estiver cadastrado, enviaremos um código de recuperação.",
        };
      }
      if (method === "POST" && path === "/api/auth/reset") {
        const token = text(body.code, "Código", 30, 150),
          password = text(body.password, "Senha", 8, 128);
        const reset = await one(
          "DELETE FROM leva_ai_private.recuperacoes WHERE token_hash=$1 AND expira_em>now() RETURNING usuario_id",
          [await digest(token)],
        );
        ensure(reset, "Código inválido ou expirado.", 400);
        await db.query(
          "UPDATE public.usuarios SET senha_hash=$1,atualizado_em=now() WHERE id=$2",
          [await hashPassword(password), reset.usuario_id],
        );
        await db.query(
          "DELETE FROM leva_ai_private.sessoes WHERE usuario_id=$1",
          [reset.usuario_id],
        );
        return { ok: true };
      }
      if (method === "GET" && path === "/api/me") return publicUser(u);
      if (method === "POST" && path === "/api/auth/logout") {
        await db.query("DELETE FROM leva_ai_private.sessoes WHERE id=$1", [
          u.sessionId,
        ]);
        return { ok: true };
      }
      if (method === "PATCH" && path === "/api/me") {
        const name = text(body.name, "Nome", 2, 150),
          phone = text(body.phone, "Telefone", 10, 20);
        await db.query(
          "UPDATE public.usuarios SET nome=$1,telefone=$2,atualizado_em=now() WHERE id=$3",
          [name, phone, u.id],
        );
        return publicUser({ ...u, name, phone });
      }
      if (method === "PATCH" && path === "/api/me/availability") {
        role(u, "prestador");
        ensure(
          typeof body.available === "boolean",
          "Disponibilidade inválida.",
        );
        await db.query(
          "UPDATE public.prestadores SET status_disponibilidade=$1 WHERE usuario_id=$2",
          [body.available ? "disponivel" : "indisponivel", u.id],
        );
        return publicUser({ ...u, available: body.available });
      }
      if (method === "GET" && path === "/api/addresses")
        return db.query(
          "SELECT id,nome AS name,ponto AS point FROM leva_ai_private.enderecos_salvos WHERE usuario_id=$1 ORDER BY nome",
          [u.id],
        );
      if (method === "POST" && path === "/api/addresses") {
        const aid = id(),
          name = text(body.name, "Nome do endereço", 2, 80),
          p = point(body.point);
        await db.query(
          "INSERT INTO leva_ai_private.enderecos_salvos(id,usuario_id,nome,ponto) VALUES($1,$2,$3,$4)",
          [aid, u.id, name, JSON.stringify(p)],
        );
        return { id: aid, name, point: p };
      }
      if (method === "GET" && path === "/api/maps/search")
        return maps.search(text(url.searchParams.get("q"), "Endereço", 4, 200));
      const pm = path.match(/^\/api\/providers\/([^/]+)$/);
      if (method === "GET" && pm) return providerDetails(uuid(pm[1]));
      if (method === "GET" && path === "/api/vehicles") {
        role(u, "prestador");
        return (
          await db.query(
            vehicleSql + " WHERE v.prestador_id=$1 ORDER BY v.criado_em",
            [u.id],
          )
        ).map(vehicleModel);
      }
      if (method === "POST" && path === "/api/vehicles")
        return saveVehicle(u, body);
      const availability = path.match(
        /^\/api\/vehicles\/([^/]+)\/availability$/,
      );
      if (method === "PATCH" && availability) {
        role(u, "prestador");
        ensure(
          typeof body.active === "boolean",
          "Informe se o veículo está ativo.",
        );
        const raw = await one(
          vehicleSql + " WHERE v.id=$1 AND v.prestador_id=$2 FOR UPDATE OF v",
          [uuid(availability[1]), u.id],
        );
        ensure(raw, "Veículo não encontrado.", 404);
        ensure(
          !body.active || raw.base_endereco,
          "Edite o veículo e selecione seu endereço base antes de ativar.",
        );
        const status = body.active ? "ativo" : "inativo";
        await db.query(
          "UPDATE public.veiculos SET status=$1 WHERE id=$2 AND prestador_id=$3",
          [status, raw.id, u.id],
        );
        return vehicleModel({ ...raw, status });
      }
      const vm = path.match(/^\/api\/vehicles\/([^/]+)$/);
      if (method === "PUT" && vm) return saveVehicle(u, body, vm[1]);
      if (method === "POST" && path === "/api/quotes") {
        if (u) role(u, "cliente");
        const input = serviceInput(body),
          route = await maps.route(
            input.origin,
            input.destination,
            input.demoRoute,
          ),
          quotes = [];
        for (const v of (
          await db.query(vehicleSql + " WHERE v.status='ativo'")
        ).map(vehicleModel)) {
          if (!(await compatible(v, input))) continue;
          const p = await one(
            "SELECT u.nome,p.avaliacao_media,p.total_avaliacoes FROM public.prestadores p JOIN public.usuarios u ON u.id=p.usuario_id WHERE u.id=$1",
            [v.provider_id],
          );
          const { base, ...publicVehicle } = v.data;
          const transportCents = Math.round(
              route.distanceKm * v.data.pricePerKmCents,
            ),
            helpersCents = input.helpers * v.data.helperPriceCents;
          const data = {
            input,
            route,
            providerName: p.nome,
            providerId: v.provider_id,
            vehicle: publicVehicle,
            rating: Number(p.total_avaliacoes)
              ? Number(p.avaliacao_media)
              : null,
            reviewCount: p.total_avaliacoes,
            providerDistanceKm:
              Math.round(distance(base, input.origin) * 10) / 10,
            transportCents,
            helpersCents,
            totalCents: transportCents + helpersCents,
          };
          const q = {
            id: id(),
            vehicle_id: v.id,
            expires_at: new Date(Date.now() + 900000).toISOString(),
            preview: !u,
            data,
          };
          if (u)
            await db.query(
              "INSERT INTO leva_ai_private.cotacoes(id,cliente_id,veiculo_id,expira_em,dados) VALUES($1,$2,$3,$4,$5)",
              [q.id, u.id, v.id, q.expires_at, JSON.stringify(data)],
            );
          quotes.push(q);
        }
        return {
          route,
          quotes: quotes.sort(
            (a, b) =>
              a.data.providerDistanceKm - b.data.providerDistanceKm ||
              a.data.totalCents - b.data.totalCents,
          ),
        };
      }
      if (method === "POST" && path === "/api/bookings") {
        role(u, "cliente");
        const q = await one(
          "SELECT * FROM leva_ai_private.cotacoes WHERE id=$1 AND cliente_id=$2 FOR UPDATE",
          [uuid(body.quoteId), u.id],
        );
        ensure(q, "Orçamento não encontrado. Faça uma nova busca.", 404);
        const existing = await one(
          "SELECT s.* FROM public.solicitacoes s JOIN public.orcamentos o ON o.solicitacao_id=s.id WHERE o.cotacao_chave=$1",
          [q.id],
        );
        if (existing) return details(existing);
        ensure(
          new Date(q.expira_em) > new Date(),
          "O orçamento expirou. Faça uma nova busca.",
          409,
        );
        const d = q.dados,
          input = serviceInput(d.input);
        const raw = await one(vehicleSql + " WHERE v.id=$1 FOR UPDATE OF v", [
          q.veiculo_id,
        ]);
        ensure(raw, "Veículo não encontrado.", 409);
        const v = vehicleModel(raw);
        ensure(
          await compatible(v, input),
          "Veículo indisponível para a data e carga.",
          409,
        );
        ensure(
          v.data.pricePerKmCents === d.vehicle.pricePerKmCents &&
            v.data.helperPriceCents === d.vehicle.helperPriceCents,
          "O preço mudou. Faça uma nova busca.",
          409,
        );
        const origin = await createAddress(u.id, input.origin, "origem"),
          destination = await createAddress(u.id, input.destination, "destino"),
          sid = id(),
          oid = id();
        await db.query(
          "INSERT INTO public.solicitacoes(id,cliente_id,endereco_origem_id,endereco_destino_id,data_desejada,tipo_servico,volume_estimado_m3,necessita_ajudantes,quantidade_ajudantes,distancia_km,rota_geojson,status,peso_kg,detalhes) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'aguardando_prestador',$12,$13)",
          [
            sid,
            u.id,
            origin,
            destination,
            input.date,
            input.type,
            input.volumeM3,
            input.helpers > 0,
            input.helpers,
            d.route.distanceKm,
            JSON.stringify({
              type: "LineString",
              coordinates: d.route.coordinates,
            }),
            input.weightKg,
            JSON.stringify(input),
          ],
        );
        await db.query(
          "INSERT INTO leva_ai_private.reservas(solicitacao_id,veiculo_id,data) VALUES($1,$2,$3)",
          [sid, v.id, input.date],
        );
        for (const description of input.items
          .split(/\n|;/)
          .filter((s) => s.trim()))
          await db.query(
            "INSERT INTO public.itens_mudanca(solicitacao_id,descricao,quantidade) VALUES($1,$2,1)",
            [sid, description.trim().slice(0, 150)],
          );
        await db.query(
          "INSERT INTO public.orcamentos(id,solicitacao_id,prestador_id,veiculo_id,ajudantes_id,quantidade_ajudantes_cotada,valor_transporte,valor_ajudantes,valor_total,tempo_estimado_min,detalhes,cotacao_chave) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)",
          [
            oid,
            sid,
            v.provider_id,
            v.id,
            raw.ajudantes_id,
            input.helpers,
            d.transportCents / 100,
            d.helpersCents / 100,
            d.totalCents / 100,
            d.route.durationMinutes,
            JSON.stringify(d),
            q.id,
          ],
        );
        const s = await one("SELECT * FROM public.solicitacoes WHERE id=$1", [
          sid,
        ]);
        await change(s, s.status, u);
        return details(s);
      }
      if (method === "GET" && path === "/api/bookings") {
        const rows =
          u.role === "cliente"
            ? await db.query(
                "SELECT * FROM public.solicitacoes WHERE cliente_id=$1 ORDER BY criado_em DESC LIMIT 100",
                [u.id],
              )
            : await db.query(
                "SELECT s.* FROM public.solicitacoes s JOIN public.orcamentos o ON o.solicitacao_id=s.id WHERE o.prestador_id=$1 ORDER BY s.criado_em DESC LIMIT 100",
                [u.id],
              );
        return Promise.all(rows.map(details));
      }
      const bm = path.match(
        /^\/api\/bookings\/([^/]+)(?:\/(status|payment|payment-check|demo-pay|review))?$/,
      );
      if (bm) {
        const s = await bookingFor(u, bm[1], method !== "GET"),
          action = bm[2];
        if (method === "GET" && !action) return details(s);
        if (method === "POST" && action === "status") {
          const allowed =
            u.role === "prestador"
              ? {
                  aguardando_prestador: [
                    "pagamento_pendente",
                    "recusado_prestador",
                  ],
                  pagamento_pendente: ["cancelado_prestador"],
                  agendado: ["a_caminho"],
                  a_caminho: ["em_andamento"],
                  em_andamento: ["concluido"],
                }
              : {
                  aguardando_prestador: ["cancelado_cliente"],
                  pagamento_pendente: ["cancelado_cliente"],
                };
          ensure(
            allowed[s.status]?.includes(body.status),
            "Esta mudança de status não é permitida.",
            409,
          );
          if (body.status.startsWith("cancelado"))
            ensure(
              !(await one(
                "SELECT p.id FROM public.pagamentos p JOIN public.servicos v ON v.id=p.servico_id WHERE v.solicitacao_id=$1",
                [s.id],
              )),
              "O Pix já foi emitido. Solicite atendimento para conciliar o cancelamento.",
              409,
            );
          if (body.status === "pagamento_pendente") {
            const o = await one(
              "SELECT * FROM public.orcamentos WHERE solicitacao_id=$1",
              [s.id],
            );
            await db.query(
              "UPDATE public.orcamentos SET status='aceito' WHERE id=$1",
              [o.id],
            );
            await db.query(
              "INSERT INTO public.servicos(solicitacao_id,orcamento_id,prestador_id,veiculo_id,status) VALUES($1,$2,$3,$4,'pagamento_pendente')",
              [s.id, o.id, o.prestador_id, o.veiculo_id],
            );
          }
          if (body.status === "recusado_prestador")
            await db.query(
              "UPDATE public.orcamentos SET status='recusado' WHERE solicitacao_id=$1",
              [s.id],
            );
          await change(s, body.status, u);
          return details(s);
        }
        if (method === "POST" && action === "payment") {
          role(u, "cliente");
          ensure(
            s.status === "pagamento_pendente",
            "Aguarde o aceite do prestador.",
            409,
          );
          const b = await details(s);
          if (!b.payment) {
            const data = await payments.create(b, u);
            const v = await one(
              "SELECT id FROM public.servicos WHERE solicitacao_id=$1",
              [s.id],
            );
            await db.query(
              "INSERT INTO public.pagamentos(servico_id,metodo,valor,gateway,gateway_transacao_id,detalhes) VALUES($1,'pix',$2,$3,$4,$5)",
              [
                v.id,
                b.data.totalCents / 100,
                data.gateway,
                data.externalId,
                JSON.stringify(data),
              ],
            );
          }
          return details(s);
        }
        if (
          method === "POST" &&
          ["payment-check", "demo-pay"].includes(action)
        ) {
          role(u, "cliente");
          const b = await details(s),
            p = b.payment;
          ensure(p, "Gere o Pix primeiro.", 409);
          if (action === "demo-pay")
            ensure(
              config.demo && p.gateway === "demo",
              "Confirmação demonstrativa desativada.",
              403,
            );
          if (p.status === "aprovado") return b;
          ensure(
            s.status === "pagamento_pendente",
            "Pagamento não permitido neste status.",
            409,
          );
          const status =
            action === "demo-pay" ? "aprovado" : await payments.check(p, b);
          await db.query(
            "UPDATE public.pagamentos SET status=$1,atualizado_em=now() WHERE id=$2",
            [status, p.id],
          );
          if (status === "aprovado") await change(s, "agendado", u);
          if (status === "recusado") await change(s, "pagamento_recusado", u);
          return details(s);
        }
        if (method === "POST" && action === "review") {
          role(u, "cliente");
          ensure(
            s.status === "concluido",
            "Avalie uma única vez, após a conclusão.",
            409,
          );
          const v = await one(
            "SELECT * FROM public.servicos WHERE solicitacao_id=$1",
            [s.id],
          );
          await db.query(
            "INSERT INTO public.avaliacoes(servico_id,cliente_id,prestador_id,nota,comentario) VALUES($1,$2,$3,$4,$5)",
            [
              v.id,
              u.id,
              v.prestador_id,
              number(body.rating, "Nota", 1, 5, true),
              text(body.comment || "", "Comentário", 0, 1000),
            ],
          );
          await change(s, "avaliado", u);
          return details(s);
        }
      }
      throw new AppError("Recurso não encontrado.", 404);
    },
  };
}
