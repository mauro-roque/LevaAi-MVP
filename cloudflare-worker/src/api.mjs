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
} from "./validation.mjs";
import { createMaps, demoPlaces, distance } from "./maps.mjs";
import { createPayments } from "./payments.mjs";

/** Regras de negócio e rotas HTTP compartilhadas pelo Worker do LevaAí. */
const activeStatuses = [
  "aguardando_prestador",
  "pagamento_pendente",
  "agendado",
  "a_caminho",
  "em_andamento",
];
const now = () => new Date().toISOString();
const decoded = (row) =>
  row
    ? {
        ...row,
        data: typeof row.data === "string" ? JSON.parse(row.data) : row.data,
      }
    : null;

/** Lê as variáveis do Worker e devolve a configuração validada da API. */
export function configuration(env) {
  const demo = env.DEMO_MODE !== "false";
  ensure(
    typeof env.JWT_SECRET === "string" && env.JWT_SECRET.length >= 32,
    "JWT_SECRET precisa ter pelo menos 32 caracteres.",
    500,
  );
  return {
    demo,
    secret: env.JWT_SECRET,
    mapsUserAgent: env.MAPS_USER_AGENT || "LevaAi-AcademicMVP/0.1",
    nominatimUrl: env.NOMINATIM_URL || "https://nominatim.openstreetmap.org",
    osrmUrl: env.OSRM_URL || "https://router.project-osrm.org",
    mpToken: env.MERCADO_PAGO_ACCESS_TOKEN,
  };
}

/** Cria dados demonstrativos apenas quando o banco ainda está vazio. */
export async function seed(db) {
  if ((await db.query("SELECT id FROM users LIMIT 1")).length) return;
  const password = await hashPassword("LevaAi@123");
  await db.transaction(async () => {
    for (const user of [
      ["demo-cliente", "Mariana Silva", "cliente@levaai.demo", "cliente"],
      [
        "demo-prestador",
        "Carlos Transportes",
        "prestador@levaai.demo",
        "prestador",
      ],
      [
        "demo-prestador-2",
        "Mudanças Horizonte",
        "horizonte@levaai.demo",
        "prestador",
      ],
    ]) {
      await db.query(
        "INSERT INTO users(id,name,email,password_hash,role,phone,created_at) VALUES($1,$2,$3,$4,$5,$6,$7) ON CONFLICT (id) DO NOTHING",
        [
          user[0],
          user[1],
          user[2],
          password,
          user[3],
          "(11) 99999-0000",
          now(),
        ],
      );
    }
    for (const vehicle of [
      [
        "demo-van",
        "demo-prestador",
        "Fiat Ducato",
        "Van",
        1500,
        12,
        450,
        2,
        8000,
      ],
      [
        "demo-fiorino",
        "demo-prestador",
        "Fiat Fiorino",
        "Utilitário",
        650,
        3.3,
        350,
        1,
        7000,
      ],
      [
        "demo-truck",
        "demo-prestador-2",
        "Mercedes-Benz Accelo",
        "Caminhão 3/4",
        3000,
        24,
        650,
        3,
        9000,
      ],
    ]) {
      const data = {
        model: vehicle[2],
        type: vehicle[3],
        capacityKg: vehicle[4],
        volumeM3: vehicle[5],
        pricePerKmCents: vehicle[6],
        helpers: vehicle[7],
        helperPriceCents: vehicle[8],
        base: demoPlaces[0],
        radiusKm: 60,
        active: true,
      };
      await db.query(
        "INSERT INTO vehicles(id,provider_id,data) VALUES($1,$2,$3) ON CONFLICT (id) DO NOTHING",
        [vehicle[0], vehicle[1], JSON.stringify(data)],
      );
    }
  });
}

/** Cria o roteador de negócio independente do transporte HTTP do Worker. */
export function createApi(db, config) {
  const maps = createMaps(config),
    payments = createPayments(config);
  const one = async (sql, values = []) => (await db.query(sql, values))[0];
  async function currentUser(authorization) {
    const claims = await verifyToken(
      (authorization || "").replace(/^Bearer /, ""),
      config.secret,
    );
    ensure(claims, "Entre na sua conta para continuar.", 401);
    const session = await one(
      "SELECT * FROM sessions WHERE id=$1 AND user_id=$2",
      [claims.jti, claims.sub],
    );
    ensure(
      session && new Date(session.expires_at) > new Date(),
      "Sua sessão expirou. Entre novamente.",
      401,
    );
    const user = await one("SELECT * FROM users WHERE id=$1", [claims.sub]);
    ensure(user, "Conta não encontrada.", 401);
    return { ...user, sessionId: claims.jti };
  }
  const role = (user, expected) =>
    ensure(
      user.role === expected,
      "Seu perfil não pode realizar esta ação.",
      403,
    );
  async function session(user) {
    const sessionId = id();
    await db.query(
      "INSERT INTO sessions(id,user_id,expires_at) VALUES($1,$2,$3)",
      [sessionId, user.id, new Date(Date.now() + 28800000).toISOString()],
    );
    return {
      user: publicUser(user),
      token: await signToken(user, config.secret, sessionId),
    };
  }
  async function bookingFor(user, bookingId) {
    const booking = decoded(
      await one("SELECT * FROM bookings WHERE id=$1", [bookingId]),
    );
    ensure(
      booking && [booking.client_id, booking.provider_id].includes(user.id),
      "Solicitação não encontrada.",
      404,
    );
    return booking;
  }
  async function change(booking, status, user) {
    await db.query("UPDATE bookings SET status=$1 WHERE id=$2", [
      status,
      booking.id,
    ]);
    await db.query(
      "INSERT INTO history(id,booking_id,actor_id,status,created_at) VALUES($1,$2,$3,$4,$5)",
      [id(), booking.id, user.id, status, now()],
    );
    booking.status = status;
  }
  async function compatible(vehicle, input) {
    const provider = await one("SELECT * FROM users WHERE id=$1", [
        vehicle.provider_id,
      ]),
      data = vehicle.data;
    if (
      !provider?.available ||
      !vehicle.active ||
      data.capacityKg < input.weightKg ||
      data.volumeM3 < input.volumeM3 ||
      data.helpers < input.helpers ||
      distance(data.base, input.origin) > data.radiusKm
    )
      return false;
    const rows = await db.query(
      "SELECT status FROM bookings WHERE vehicle_id=$1 AND service_date=$2",
      [vehicle.id, input.date],
    );
    return !rows.some((row) => activeStatuses.includes(row.status));
  }
  async function details(booking) {
    const payment = decoded(
      await one("SELECT * FROM payments WHERE booking_id=$1", [booking.id]),
    );
    const review = await one("SELECT * FROM reviews WHERE booking_id=$1", [
      booking.id,
    ]);
    const history = await db.query(
      "SELECT status,created_at FROM history WHERE booking_id=$1 ORDER BY created_at,id",
      [booking.id],
    );
    const client = await one("SELECT name,phone FROM users WHERE id=$1", [
      booking.client_id,
    ]);
    const provider = await one("SELECT name,phone FROM users WHERE id=$1", [
      booking.provider_id,
    ]);
    return {
      ...booking,
      payment,
      review: review || null,
      history,
      client,
      provider,
    };
  }

  return {
    async handle({ method, path, url, body, authorization }) {
      if (method === "GET" && path === "/api/config")
        return {
          demo: config.demo,
          demoPlaces: config.demo ? demoPlaces : [],
          paymentMode: config.demo ? "demo" : "mercado_pago",
        };
      if (method === "GET" && path === "/api/health")
        return { status: "ok", runtime: "cloudflare-worker" };
      const publicRoute = [
        "/api/auth/login",
        "/api/auth/register",
        "/api/config",
        "/api/health",
      ].includes(path);
      const user = publicRoute ? null : await currentUser(authorization);
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
          !(await one("SELECT id FROM users WHERE email=$1", [email])),
          "Este e-mail já está cadastrado.",
          409,
        );
        const created = {
          id: id(),
          name,
          email,
          role: body.role,
          phone,
          available: true,
        };
        await db.query(
          "INSERT INTO users(id,name,email,password_hash,role,phone,created_at) VALUES($1,$2,$3,$4,$5,$6,$7)",
          [
            created.id,
            name,
            email,
            await hashPassword(password),
            created.role,
            phone,
            now(),
          ],
        );
        return session(created);
      }
      if (method === "POST" && path === "/api/auth/login") {
        const email = text(body.email, "E-mail", 3, 150).toLowerCase(),
          password = text(body.password, "Senha", 1, 128),
          found = await one("SELECT * FROM users WHERE email=$1", [email]);
        const valid = found
          ? await verifyPassword(password, found.password_hash)
          : false;
        ensure(found && valid, "E-mail ou senha incorretos.", 401);
        return session(found);
      }
      if (method === "GET" && path === "/api/me") return publicUser(user);
      if (method === "POST" && path === "/api/auth/logout") {
        await db.query("DELETE FROM sessions WHERE id=$1", [user.sessionId]);
        return { ok: true };
      }
      if (method === "PATCH" && path === "/api/me/availability") {
        role(user, "prestador");
        ensure(
          typeof body.available === "boolean",
          "Disponibilidade inválida.",
        );
        await db.query("UPDATE users SET available=$1 WHERE id=$2", [
          body.available,
          user.id,
        ]);
        return publicUser({ ...user, available: body.available });
      }
      if (method === "GET" && path === "/api/maps/search")
        return maps.search(text(url.searchParams.get("q"), "Endereço", 4, 200));
      if (method === "GET" && path === "/api/vehicles") {
        role(user, "prestador");
        return (
          await db.query("SELECT * FROM vehicles WHERE provider_id=$1", [
            user.id,
          ])
        ).map(decoded);
      }
      if (method === "POST" && path === "/api/vehicles") {
        role(user, "prestador");
        const data = vehicleInput(body),
          vehicleId = id();
        await db.query(
          "INSERT INTO vehicles(id,provider_id,active,data) VALUES($1,$2,$3,$4)",
          [vehicleId, user.id, data.active, JSON.stringify(data)],
        );
        return {
          id: vehicleId,
          provider_id: user.id,
          active: data.active,
          data,
        };
      }
      const vehicleMatch = path.match(/^\/api\/vehicles\/([^/]+)$/);
      if (method === "PUT" && vehicleMatch) {
        role(user, "prestador");
        ensure(
          await one("SELECT id FROM vehicles WHERE id=$1 AND provider_id=$2", [
            vehicleMatch[1],
            user.id,
          ]),
          "Veículo não encontrado.",
          404,
        );
        const data = vehicleInput(body);
        await db.query("UPDATE vehicles SET active=$1,data=$2 WHERE id=$3", [
          data.active,
          JSON.stringify(data),
          vehicleMatch[1],
        ]);
        return { ok: true };
      }
      if (method === "POST" && path === "/api/quotes") {
        role(user, "cliente");
        const input = serviceInput(body),
          route = await maps.route(
            input.origin,
            input.destination,
            input.demoRoute,
          ),
          vehicles = (
            await db.query("SELECT * FROM vehicles WHERE active=TRUE")
          ).map(decoded),
          quotes = [];
        for (const vehicle of vehicles) {
          if (!(await compatible(vehicle, input))) continue;
          const data = vehicle.data,
            provider = await one("SELECT name FROM users WHERE id=$1", [
              vehicle.provider_id,
            ]),
            reviews = await db.query(
              "SELECT rating FROM reviews WHERE provider_id=$1",
              [vehicle.provider_id],
            ),
            transportCents = Math.round(
              route.distanceKm * data.pricePerKmCents,
            ),
            helpersCents = input.helpers * data.helperPriceCents;
          const quoteData = {
              input,
              route,
              providerName: provider.name,
              providerId: vehicle.provider_id,
              vehicle: data,
              rating: reviews.length
                ? reviews.reduce((sum, item) => sum + item.rating, 0) /
                  reviews.length
                : null,
              reviewCount: reviews.length,
              providerDistanceKm:
                Math.round(distance(data.base, input.origin) * 10) / 10,
              transportCents,
              helpersCents,
              totalCents: transportCents + helpersCents,
            },
            quote = {
              id: id(),
              vehicle_id: vehicle.id,
              expires_at: new Date(Date.now() + 900000).toISOString(),
              data: quoteData,
            };
          await db.query(
            "INSERT INTO quotes(id,client_id,vehicle_id,expires_at,data) VALUES($1,$2,$3,$4,$5)",
            [
              quote.id,
              user.id,
              vehicle.id,
              quote.expires_at,
              JSON.stringify(quoteData),
            ],
          );
          quotes.push(quote);
        }
        return {
          route,
          quotes: quotes.sort((a, b) => a.data.totalCents - b.data.totalCents),
        };
      }
      if (method === "POST" && path === "/api/bookings") {
        role(user, "cliente");
        const quote = decoded(
          await one("SELECT * FROM quotes WHERE id=$1 AND client_id=$2", [
            text(body.quoteId, "Orçamento"),
            user.id,
          ]),
        );
        ensure(quote, "Orçamento não encontrado.", 404);
        const existing = decoded(
          await one("SELECT * FROM bookings WHERE quote_id=$1", [quote.id]),
        );
        if (existing) return details(existing);
        ensure(
          new Date(quote.expires_at) > new Date(),
          "O orçamento expirou. Faça uma nova busca.",
          409,
        );
        serviceInput(quote.data.input);
        const vehicle = decoded(
          await one("SELECT * FROM vehicles WHERE id=$1", [quote.vehicle_id]),
        );
        ensure(
          vehicle && (await compatible(vehicle, quote.data.input)),
          "O veículo não está mais disponível para esta solicitação.",
          409,
        );
        ensure(
          vehicle.data.pricePerKmCents === quote.data.vehicle.pricePerKmCents &&
            vehicle.data.helperPriceCents ===
              quote.data.vehicle.helperPriceCents,
          "O preço foi atualizado. Faça uma nova cotação.",
          409,
        );
        const booking = {
          id: id(),
          quote_id: quote.id,
          client_id: user.id,
          provider_id: vehicle.provider_id,
          vehicle_id: vehicle.id,
          service_date: quote.data.input.date,
          status: "aguardando_prestador",
          data: quote.data,
          created_at: now(),
        };
        await db.query(
          "INSERT INTO bookings(id,quote_id,client_id,provider_id,vehicle_id,service_date,status,data,created_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)",
          [
            booking.id,
            quote.id,
            user.id,
            vehicle.provider_id,
            vehicle.id,
            booking.service_date,
            booking.status,
            JSON.stringify(booking.data),
            booking.created_at,
          ],
        );
        await change(booking, booking.status, user);
        return details(booking);
      }
      if (method === "GET" && path === "/api/bookings") {
        const field = user.role === "cliente" ? "client_id" : "provider_id";
        return Promise.all(
          (
            await db.query(
              `SELECT * FROM bookings WHERE ${field}=$1 ORDER BY created_at DESC`,
              [user.id],
            )
          ).map((row) => details(decoded(row))),
        );
      }
      const bookingMatch = path.match(
        /^\/api\/bookings\/([^/]+)(?:\/(status|payment|payment-check|demo-pay|review))?$/,
      );
      if (bookingMatch) {
        const booking = await bookingFor(user, bookingMatch[1]),
          action = bookingMatch[2];
        if (method === "GET" && !action) return details(booking);
        if (method === "POST" && action === "status") {
          const allowed =
            user.role === "prestador"
              ? {
                  aguardando_prestador: [
                    "pagamento_pendente",
                    "recusado_prestador",
                  ],
                  agendado: ["a_caminho"],
                  a_caminho: ["em_andamento"],
                  em_andamento: ["concluido"],
                }
              : {
                  aguardando_prestador: ["cancelado_cliente"],
                  pagamento_pendente: ["cancelado_cliente"],
                };
          ensure(
            allowed[booking.status]?.includes(body.status),
            "Esta mudança de status não é permitida.",
            409,
          );
          if (body.status === "cancelado_cliente")
            ensure(
              !(await one("SELECT id FROM payments WHERE booking_id=$1", [
                booking.id,
              ])),
              "O Pix já foi emitido. O cancelamento precisa ser conciliado pelo atendimento.",
              409,
            );
          await change(booking, body.status, user);
          return details(booking);
        }
        if (method === "POST" && action === "payment") {
          role(user, "cliente");
          ensure(
            booking.status === "pagamento_pendente",
            "Aguarde o aceite do prestador para pagar.",
            409,
          );
          let payment = await one(
            "SELECT * FROM payments WHERE booking_id=$1",
            [booking.id],
          );
          if (!payment) {
            const data = await payments.create(booking, user);
            await db.query(
              "INSERT INTO payments(id,booking_id,amount_cents,status,gateway,external_id,data) VALUES($1,$2,$3,$4,$5,$6,$7)",
              [
                id(),
                booking.id,
                booking.data.totalCents,
                "pendente",
                data.gateway,
                data.externalId,
                JSON.stringify(data),
              ],
            );
          }
          return details(booking);
        }
        if (
          method === "POST" &&
          ["payment-check", "demo-pay"].includes(action)
        ) {
          role(user, "cliente");
          const payment = decoded(
            await one("SELECT * FROM payments WHERE booking_id=$1", [
              booking.id,
            ]),
          );
          ensure(payment, "Gere o Pix primeiro.", 409);
          if (action === "demo-pay")
            ensure(
              config.demo && payment.gateway === "demo",
              "Confirmação demonstrativa desativada.",
              403,
            );
          if (payment.status === "aprovado") return details(booking);
          ensure(
            booking.status === "pagamento_pendente",
            "O pagamento não pode ser confirmado neste status.",
            409,
          );
          const status =
            action === "demo-pay"
              ? "aprovado"
              : await payments.check(payment, booking);
          await db.query("UPDATE payments SET status=$1 WHERE id=$2", [
            status,
            payment.id,
          ]);
          if (status === "aprovado") await change(booking, "agendado", user);
          if (status === "recusado")
            await change(booking, "pagamento_recusado", user);
          return details(booking);
        }
        if (method === "POST" && action === "review") {
          role(user, "cliente");
          ensure(
            booking.status === "concluido",
            "Você pode avaliar depois da conclusão, uma única vez.",
            409,
          );
          const rating = number(body.rating, "Nota", 1, 5, true),
            comment = text(body.comment || "", "Comentário", 0, 1000);
          await db.query(
            "INSERT INTO reviews(id,booking_id,client_id,provider_id,rating,comment,created_at) VALUES($1,$2,$3,$4,$5,$6,$7)",
            [
              id(),
              booking.id,
              user.id,
              booking.provider_id,
              rating,
              comment,
              now(),
            ],
          );
          await change(booking, "avaliado", user);
          return details(booking);
        }
      }
      throw new AppError("Recurso não encontrado.", 404);
    },
  };
}
