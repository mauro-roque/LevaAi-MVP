import test from "node:test";
import assert from "node:assert/strict";
import { createApi } from "../src/normalized-api.mjs";

/** Valida o endpoint público que apresenta distância antes da cotação. */
test("rota pública usa o provedor e devolve distância e duração", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url) => {
    assert.match(String(url), /route\/v1\/driving/);
    return new Response(
      JSON.stringify({
        code: "Ok",
        routes: [
          {
            distance: 12540,
            duration: 1430,
            geometry: {
              coordinates: [
                [-46.6333, -23.5505],
                [-46.6576, -23.5874],
              ],
            },
          },
        ],
      }),
      { status: 200 },
    );
  };
  try {
    const api = createApi(
      { query: async () => [] },
      {
        secret: "s".repeat(64),
        mapsUserAgent: "LevaAi tests",
        nominatimUrl: "https://nominatim.test",
        osrmUrl: "https://osrm.test",
      },
    );
    const route = await api.handle({
      method: "POST",
      path: "/api/maps/route",
      url: new URL("https://app.test/api/maps/route"),
      body: {
        origin: { label: "Praça da Sé, São Paulo", lat: -23.5505, lon: -46.6333 },
        destination: {
          label: "Parque Ibirapuera, São Paulo",
          lat: -23.5874,
          lon: -46.6576,
        },
      },
    });
    assert.deepEqual(route, {
      distanceKm: 12.6,
      durationMinutes: 24,
      demo: false,
      coordinates: [
        [-46.6333, -23.5505],
        [-46.6576, -23.5874],
      ],
    });
  } finally {
    globalThis.fetch = originalFetch;
  }
});
