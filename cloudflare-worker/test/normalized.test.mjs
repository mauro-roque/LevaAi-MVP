import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { PGlite } from "@electric-sql/pglite";
import { createApi, seed } from "../src/normalized-api.mjs";
import { demoPlaces } from "../src/maps.mjs";

test("modelo original: busca visitante, autorização, reserva, Pix, estados e avaliação", async () => {
  const pg = new PGlite();
  const base = (
    await readFile(
      new URL(
        "../../supabase/migrations/202609200001_base_original.sql",
        import.meta.url,
      ),
      "utf8",
    )
  ).replace('CREATE EXTENSION IF NOT EXISTS "pgcrypto";', "");
  const migration = await readFile(
    new URL("../../supabase/migrations/202609200002_mvp.sql", import.meta.url),
    "utf8",
  );
  await pg.exec(base);
  await pg.exec(migration);
  // Reaplicação deve preservar o banco.
  await pg.exec(base);
  await pg.exec(migration);
  const db = { query: async (s, p = []) => (await pg.query(s, p)).rows };
  await pg.exec("BEGIN");
  await seed(db);
  await pg.exec("COMMIT");
  const cfg = { demo: true, secret: "s".repeat(64) };
  const api = createApi(db, cfg);
  async function call(path, { method = "GET", body = {}, token } = {}) {
    await pg.exec("BEGIN");
    try {
      const r = await api.handle({
        method,
        path: "/api" + path,
        url: new URL("https://test/api" + path),
        body,
        authorization: token ? "Bearer " + token : undefined,
      });
      await pg.exec("COMMIT");
      return r;
    } catch (e) {
      await pg.exec("ROLLBACK");
      throw e;
    }
  }
  try {
    const input = {
      origin: demoPlaces[0],
      destination: demoPlaces[1],
      date: new Date(Date.now() + 86400000).toISOString().slice(0, 10),
      type: "frete",
      items: "1 sofá;4 caixas",
      weightKg: 100,
      volumeM3: 2,
      helpers: 1,
      demoRoute: true,
    };
    const previews = await call("/quotes", { method: "POST", body: input });
    assert.equal(previews.quotes.length, 3);
    assert.equal(previews.quotes[0].preview, true);
    assert.equal(
      (
        await db.query(
          "SELECT count(*)::int AS n FROM leva_ai_private.cotacoes",
        )
      )[0].n,
      0,
    );
    assert.equal(previews.quotes[0].data.vehicle.base, undefined);
    await assert.rejects(
      () =>
        call("/bookings", {
          method: "POST",
          body: { quoteId: previews.quotes[0].id },
        }),
      (e) => e.status === 401,
    );
    const login = async (email) =>
      call("/auth/login", {
        method: "POST",
        body: { email, password: "LevaAi@123" },
      });
    const client = await login("cliente@levaai.demo"),
      provider = await login("prestador@levaai.demo"),
      other = await login("horizonte@levaai.demo");
    const quotes = await call("/quotes", {
      method: "POST",
      body: input,
      token: client.token,
    });
    const q = quotes.quotes.find((q) => q.data.providerId === provider.user.id);
    const booking = await call("/bookings", {
      method: "POST",
      body: { quoteId: q.id },
      token: client.token,
    });
    assert.equal(booking.status, "aguardando_prestador");
    assert.equal(booking.service_date, input.date);
    const blocked = await call("/quotes", {
      method: "POST",
      body: input,
      token: client.token,
    });
    assert.ok(
      !blocked.quotes.some((other) => other.vehicle_id === q.vehicle_id),
    );
    const tooHeavy = await call("/quotes", {
      method: "POST",
      body: { ...input, weightKg: 20000 },
    });
    assert.equal(tooHeavy.quotes.length, 0);
    const again = await call("/bookings", {
      method: "POST",
      body: { quoteId: q.id },
      token: client.token,
    });
    assert.equal(again.id, booking.id);
    assert.equal(
      (await db.query("SELECT count(*)::int AS n FROM public.solicitacoes"))[0]
        .n,
      1,
    );
    assert.equal(
      (await db.query("SELECT count(*)::int AS n FROM public.itens_mudanca"))[0]
        .n,
      2,
    );
    await assert.rejects(
      () => call("/bookings/" + booking.id, { token: other.token }),
      (e) => e.status === 404,
    );
    await assert.rejects(
      () =>
        call("/bookings/" + booking.id + "/payment", {
          method: "POST",
          token: client.token,
        }),
      (e) => e.status === 409,
    );
    await assert.rejects(
      () =>
        call("/bookings/" + booking.id + "/status", {
          method: "POST",
          body: { status: "concluido" },
          token: provider.token,
        }),
      (e) => e.status === 409,
    );
    await call("/bookings/" + booking.id + "/status", {
      method: "POST",
      body: { status: "pagamento_pendente" },
      token: provider.token,
    });
    const p = await call("/bookings/" + booking.id + "/payment", {
      method: "POST",
      token: client.token,
    });
    assert.equal(p.payment.gateway, "demo");
    await assert.rejects(
      () =>
        call("/bookings/" + booking.id + "/status", {
          method: "POST",
          body: { status: "cancelado_cliente" },
          token: client.token,
        }),
      (e) => e.status === 409,
    );
    const paid = await call("/bookings/" + booking.id + "/demo-pay", {
      method: "POST",
      token: client.token,
    });
    assert.equal(paid.status, "agendado");
    for (const status of ["a_caminho", "em_andamento", "concluido"])
      await call("/bookings/" + booking.id + "/status", {
        method: "POST",
        body: { status },
        token: provider.token,
      });
    const reviewed = await call("/bookings/" + booking.id + "/review", {
      method: "POST",
      body: { rating: 5, comment: "Muito bom" },
      token: client.token,
    });
    assert.equal(reviewed.status, "avaliado");
    await assert.rejects(
      () =>
        call("/bookings/" + booking.id + "/review", {
          method: "POST",
          body: { rating: 4 },
          token: client.token,
        }),
      (e) => e.status === 409,
    );
    const info = await call("/providers/" + provider.user.id);
    assert.equal(info.rating, 5);
    assert.equal(info.reviews.length, 1);
    const profile = await call("/me", {
      method: "PATCH",
      body: { name: "Mariana Teste", phone: "11988880000" },
      token: client.token,
    });
    assert.equal(profile.name, "Mariana Teste");
    await call("/addresses", {
      method: "POST",
      body: { name: "Casa", point: demoPlaces[0] },
      token: client.token,
    });
    assert.equal((await call("/addresses", { token: client.token })).length, 1);
    assert.equal(
      (await call("/addresses", { token: provider.token })).length,
      0,
    );
    const newUser = await call("/auth/register", {
      method: "POST",
      body: {
        name: "Novo Cliente",
        email: "novo@example.com",
        password: "SenhaForte123",
        phone: "11955550000",
        role: "cliente",
      },
    });
    assert.equal(newUser.user.role, "cliente");
    await assert.rejects(
      () =>
        call("/vehicles", {
          method: "POST",
          body: q.data.vehicle,
          token: client.token,
        }),
      (e) => e.status === 403,
    );
    const vehicle = await call("/vehicles", {
      method: "POST",
      body: { ...q.data.vehicle, type: "van", base: demoPlaces[0] },
      token: provider.token,
    });
    assert.ok(vehicle.id);
    assert.equal(vehicle.active, true);
    const paused = await call("/vehicles/" + vehicle.id + "/availability", {
      method: "PATCH",
      body: { active: false },
      token: provider.token,
    });
    assert.equal(paused.active, false);
    const resumed = await call("/vehicles/" + vehicle.id + "/availability", {
      method: "PATCH",
      body: { active: true },
      token: provider.token,
    });
    assert.equal(resumed.active, true);
    await assert.rejects(
      () =>
        call("/vehicles/" + vehicle.id + "/availability", {
          method: "PATCH",
          body: { active: false },
          token: other.token,
        }),
      (e) => e.status === 404,
    );
    await call("/vehicles/" + vehicle.id, {
      method: "PUT",
      body: { ...vehicle.data, active: false },
      token: provider.token,
    });
    assert.equal(
      (await call("/vehicles", { token: provider.token })).find(
        (v) => v.id === vehicle.id,
      ).active,
      false,
    );
    await assert.rejects(
      () =>
        call("/vehicles/" + vehicle.id, {
          method: "PUT",
          body: vehicle.data,
          token: other.token,
        }),
      (e) => e.status === 404,
    );
    const secondQuotes = await call("/quotes", {
      method: "POST",
      body: input,
      token: client.token,
    });
    const second = await call("/bookings", {
      method: "POST",
      body: { quoteId: secondQuotes.quotes[0].id },
      token: client.token,
    });
    await call("/bookings/" + second.id + "/status", {
      method: "POST",
      body: { status: "cancelado_cliente" },
      token: client.token,
    });
    assert.equal(
      (
        await db.query(
          "SELECT count(*)::int AS n FROM leva_ai_private.reservas WHERE solicitacao_id=$1",
          [second.id],
        )
      )[0].n,
      0,
    );
    await call("/auth/logout", { method: "POST", token: newUser.token });
    await assert.rejects(
      () => call("/me", { token: newUser.token }),
      (e) => e.status === 401,
    );
    await assert.rejects(
      () =>
        call("/auth/reset", {
          method: "POST",
          body: { code: "a".repeat(72), password: "NovaSenha123" },
        }),
      (e) => e.status === 400,
    );
  } finally {
    await pg.close();
  }
});
