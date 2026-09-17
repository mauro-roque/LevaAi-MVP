import { test } from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import { openDatabase } from "../src/db.mjs";
import { configuration, createApp, seed } from "../src/app.mjs";
import { demoPlaces, createMaps } from "../src/maps.mjs";
import { createPayments } from "../src/payments.mjs";
import { signToken, verifyToken } from "../src/auth.mjs";

test("MVP: cadastro, autorização, orçamento, reserva, Pix, status e avaliação", async (t) => {
  const db = await openDatabase({ file: ":memory:" });
  await seed(db);
  const config = configuration({
    DEMO_MODE: "true",
    JWT_SECRET: "test-secret-not-used-in-production",
  });
  const server = createApp(db, config);
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(async () => {
    server.closeAllConnections();
    await new Promise((r) => server.close(r));
    await db.close();
  });
  const base = `http://127.0.0.1:${server.address().port}/api`;
  async function call(
    path,
    { token, body, method = body ? "POST" : "GET" } = {},
  ) {
    const response = await fetch(base + path, {
      method,
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    return { status: response.status, data: await response.json() };
  }
  const login = async (email) => {
    const result = await call("/auth/login", {
      body: { email, password: "LevaAi@123" },
    });
    assert.equal(result.status, 200);
    return result.data.token;
  };
  const client = await login("cliente@levaai.demo"),
    provider = await login("prestador@levaai.demo"),
    otherProvider = await login("horizonte@levaai.demo");
  const input = {
    origin: demoPlaces[0],
    destination: demoPlaces[1],
    date: "2099-10-12",
    type: "mudanca",
    items: "1 sofá e 4 caixas",
    weightKg: 100,
    volumeM3: 2,
    helpers: 1,
    demoRoute: true,
  };
  let quote, booking;
  await t.test(
    "senhas protegidas, login incorreto e sessão inválida",
    async () => {
      const rows = await db.query("SELECT password_hash FROM users");
      assert(rows.every((r) => !r.password_hash.includes("LevaAi@123")));
      assert.equal(
        (
          await call("/auth/login", {
            body: { email: "cliente@levaai.demo", password: "errada" },
          })
        ).status,
        401,
      );
      assert.equal((await call("/bookings")).status, 401);
      assert.equal(
        (await call("/bookings", { token: client + "bad" })).status,
        401,
      );
    },
  );
  let newcomer;
  await t.test("cadastro e duplicidade de e-mail normalizada", async () => {
    const body = {
      name: "Novo cliente",
      email: "novo@example.com",
      password: "senha-segura-123",
      phone: "11987654321",
      role: "cliente",
    };
    const registered = await call("/auth/register", { body });
    assert.equal(registered.status, 200);
    newcomer = registered.data.token;
    assert(!("password_hash" in registered.data.user));
    assert.equal(
      (
        await call("/auth/register", {
          body: { ...body, email: "NOVO@example.com" },
        })
      ).status,
      409,
    );
  });
  await t.test("perfil, veículo e dados inválidos", async () => {
    assert.equal((await call("/vehicles", { token: client })).status, 403);
    assert.equal(
      (await call("/quotes", { token: provider, body: input })).status,
      403,
    );
    for (const invalid of [
      { weightKg: -1 },
      { helpers: 1.5 },
      { date: "2020-01-01" },
      { date: "2099-02-31" },
      { origin: null },
      { destination: demoPlaces[0] },
    ]) {
      assert.equal(
        (
          await call("/quotes", {
            token: client,
            body: { ...input, ...invalid },
          })
        ).status,
        400,
      );
    }
    const body = {
      model: "Teste VUC",
      type: "VUC",
      capacityKg: 4000,
      volumeM3: 25,
      pricePerKmCents: 700,
      helpers: 2,
      helperPriceCents: 10000,
      base: demoPlaces[0],
      radiusKm: 40,
      active: false,
    };
    const created = await call("/vehicles", { token: provider, body });
    assert.equal(created.status, 200);
    assert.equal(
      (
        await call(`/vehicles/${created.data.id}`, {
          token: otherProvider,
          method: "PUT",
          body,
        })
      ).status,
      404,
    );
    assert.equal(
      (
        await call(`/vehicles/${created.data.id}`, {
          token: provider,
          method: "PUT",
          body: { ...body, pricePerKmCents: -1 },
        })
      ).status,
      400,
    );
  });
  await t.test(
    "capacidade, ajudantes, preço no servidor e indisponibilidade",
    async () => {
      assert.equal(
        (
          await call("/quotes", {
            token: client,
            body: { ...input, weightKg: 9000 },
          })
        ).data.quotes.length,
        0,
      );
      assert.equal(
        (
          await call("/quotes", {
            token: client,
            body: { ...input, helpers: 6 },
          })
        ).data.quotes.length,
        0,
      );
      const result = await call("/quotes", {
        token: client,
        body: { ...input, totalCents: 1 },
      });
      assert.equal(result.status, 200);
      assert.equal(result.data.quotes.length, 3);
      for (var i = 1; i < result.data.quotes.length; i++) {
        const previous = result.data.quotes[i - 1].data;
        const current = result.data.quotes[i].data;
        assert(
          previous.providerDistanceKm < current.providerDistanceKm ||
            (previous.providerDistanceKm === current.providerDistanceKm &&
              previous.totalCents <= current.totalCents),
        );
      }
      quote = result.data.quotes.find((q) => q.vehicle_id === "demo-van");
      assert.equal(
        quote.data.totalCents,
        Math.round(result.data.route.distanceKm * 450) + 8000,
      );
      await call("/me/availability", {
        token: provider,
        method: "PATCH",
        body: { available: false },
      });
      assert.equal(
        (await call("/quotes", { token: client, body: input })).data.quotes
          .length,
        1,
      );
      assert.equal(
        (
          await call("/bookings", {
            token: client,
            body: { quoteId: quote.id },
          })
        ).status,
        409,
      );
      await call("/me/availability", {
        token: provider,
        method: "PATCH",
        body: { available: true },
      });
    },
  );
  await t.test(
    "orçamento expirado e reserva concorrente sem duplicação",
    async () => {
      const expired = (await call("/quotes", { token: client, body: input }))
        .data.quotes[0];
      await db.query("UPDATE quotes SET expires_at=$1 WHERE id=$2", [
        "2000-01-01",
        expired.id,
      ]);
      assert.equal(
        (
          await call("/bookings", {
            token: client,
            body: { quoteId: expired.id },
          })
        ).status,
        409,
      );
      const second = (
        await call("/quotes", { token: newcomer, body: input })
      ).data.quotes.find((q) => q.vehicle_id === "demo-van");
      const results = await Promise.all([
        call("/bookings", {
          token: client,
          body: { quoteId: quote.id, totalCents: 1 },
        }),
        call("/bookings", { token: newcomer, body: { quoteId: second.id } }),
      ]);
      assert.deepEqual(results.map((r) => r.status).sort(), [200, 409]);
      // A primeira requisição entrou na fila antes da segunda.
      assert.equal(results[0].status, 200);
      booking = results[0].data;
      const duplicate = await call("/bookings", {
        token: client,
        body: { quoteId: quote.id },
      });
      assert.equal(duplicate.data.id, booking.id);
      assert.equal(duplicate.data.data.totalCents, quote.data.totalCents);
    },
  );
  await t.test("privacidade e transições de status inválidas", async () => {
    assert.equal(
      (await call(`/bookings/${booking.id}`, { token: newcomer })).status,
      404,
    );
    assert.equal(
      (await call(`/bookings/${booking.id}`, { token: otherProvider })).status,
      404,
    );
    assert.equal((await call("/bookings", { token: newcomer })).data.length, 0);
    assert.equal(
      (
        await call(`/bookings/${booking.id}/payment`, {
          token: client,
          body: {},
        })
      ).status,
      409,
    );
    assert.equal(
      (
        await call(`/bookings/${booking.id}/status`, {
          token: client,
          body: { status: "concluido" },
        })
      ).status,
      409,
    );
    assert.equal(
      (
        await call(`/bookings/${booking.id}/status`, {
          token: provider,
          body: { status: "em_andamento" },
        })
      ).status,
      409,
    );
  });
  await t.test("aceite, Pix idempotente e pagamento obrigatório", async () => {
    assert.equal(
      (
        await call(`/bookings/${booking.id}/status`, {
          token: provider,
          body: { status: "pagamento_pendente" },
        })
      ).status,
      200,
    );
    assert.equal(
      (
        await call(`/bookings/${booking.id}/status`, {
          token: provider,
          body: { status: "a_caminho" },
        })
      ).status,
      409,
    );
    const a = await call(`/bookings/${booking.id}/payment`, {
      token: client,
      body: {},
    });
    const b = await call(`/bookings/${booking.id}/payment`, {
      token: client,
      body: {},
    });
    assert.equal(a.data.payment.id, b.data.payment.id);
    assert.equal(a.data.payment.amount_cents, quote.data.totalCents);
    assert.equal(a.data.payment.data.demo, true);
    assert.equal(a.data.payment.data.qrCode, "");
    assert.equal(
      (
        await call(`/bookings/${booking.id}/demo-pay`, {
          token: provider,
          body: {},
        })
      ).status,
      403,
    );
    assert.equal(
      (
        await call(`/bookings/${booking.id}/status`, {
          token: client,
          body: { status: "cancelado_cliente" },
        })
      ).status,
      409,
    );
    const paid = await call(`/bookings/${booking.id}/demo-pay`, {
      token: client,
      body: {},
    });
    assert.equal(paid.data.status, "agendado");
    assert.equal(paid.data.payment.status, "aprovado");
    assert.equal(
      (
        await call(`/bookings/${booking.id}/demo-pay`, {
          token: client,
          body: {},
        })
      ).data.status,
      "agendado",
    );
  });
  await t.test("execução, avaliação única e histórico auditável", async () => {
    assert.equal(
      (
        await call(`/bookings/${booking.id}/review`, {
          token: client,
          body: { rating: 5 },
        })
      ).status,
      409,
    );
    for (const status of ["a_caminho", "em_andamento", "concluido"])
      assert.equal(
        (
          await call(`/bookings/${booking.id}/status`, {
            token: provider,
            body: { status },
          })
        ).data.status,
        status,
      );
    assert.equal(
      (
        await call(`/bookings/${booking.id}/review`, {
          token: client,
          body: { rating: 6 },
        })
      ).status,
      400,
    );
    const result = await call(`/bookings/${booking.id}/review`, {
      token: client,
      body: { rating: 5, comment: "Muito bom!" },
    });
    assert.equal(result.data.status, "avaliado");
    assert.equal(result.data.review.rating, 5);
    assert.deepEqual(
      result.data.history.map((h) => h.status),
      [
        "aguardando_prestador",
        "pagamento_pendente",
        "agendado",
        "a_caminho",
        "em_andamento",
        "concluido",
        "avaliado",
      ],
    );
    assert.equal(
      (
        await call(`/bookings/${booking.id}/review`, {
          token: client,
          body: { rating: 4 },
        })
      ).status,
      409,
    );
    const resultQuotes = (await call("/quotes", { token: client, body: input }))
      .data.quotes;
    assert.equal(
      resultQuotes.find((q) => q.vehicle_id === "demo-van").data.rating,
      5,
    );
  });
  await t.test(
    "recusa e cancelamento liberam o veículo; logout revoga JWT",
    async () => {
      for (const target of ["cancelado_cliente", "recusado_prestador"]) {
        const q = (
          await call("/quotes", { token: client, body: input })
        ).data.quotes.find((q) => q.vehicle_id === "demo-van");
        const row = (
          await call("/bookings", { token: client, body: { quoteId: q.id } })
        ).data;
        assert.equal(
          (
            await call(`/bookings/${row.id}/status`, {
              token: target === "cancelado_cliente" ? client : provider,
              body: { status: target },
            })
          ).data.status,
          target,
        );
      }
      await call("/auth/logout", { token: newcomer, body: {} });
      assert.equal((await call("/me", { token: newcomer })).status, 401);
    },
  );
});

test("modo real não permite fixtures, exige configuração e não simula Pix", async () => {
  assert.throws(() => configuration({ DEMO_MODE: "false" }));
  const config = configuration({
    DEMO_MODE: "false",
    JWT_SECRET: "a".repeat(32),
    DATABASE_URL: "postgresql://localhost/test",
  });
  await assert.rejects(
    () => createMaps(config).route(demoPlaces[0], demoPlaces[1], true),
    /desativada/,
  );
  await assert.rejects(
    () =>
      createPayments(config).create(
        { id: "x", data: { totalCents: 100 } },
        { email: "test@example.com" },
      ),
    /não configurado/,
  );
  const token = signToken({ id: "test" }, "secret", "session");
  assert.equal(verifyToken(token, "wrong"), null);
  assert.equal(verifyToken(token, "secret").sub, "test");
});
