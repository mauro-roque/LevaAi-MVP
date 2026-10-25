import test from "node:test";
import assert from "node:assert/strict";
import { createApi } from "../src/normalized-api.mjs";

/** Garante municípios únicos e no padrão curto apresentado no seletor de cidades. */
test("busca de cidade remove duplicidade e exibe município com UF", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url) => {
    const request = new URL(url);
    assert.equal(request.searchParams.get("featureType"), "city");
    assert.equal(request.searchParams.get("addressdetails"), "1");
    return new Response(
      JSON.stringify([
        {
          name: "Piraju",
          display_name: "Piraju, São Paulo, Brasil",
          lat: "-23.2",
          lon: "-49.3",
          address: {
            town: "Piraju",
            state: "São Paulo",
            "ISO3166-2-lvl4": "BR-SP",
          },
        },
        {
          name: "Piraju",
          display_name: "Piraju, Região de Ourinhos, São Paulo, Brasil",
          lat: "-23.2",
          lon: "-49.3",
          address: { municipality: "Piraju", state: "São Paulo" },
        },
      ]),
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
    const cities = await api.handle({
      method: "GET",
      path: "/api/maps/search",
      url: new URL("https://app.test/api/maps/search?q=Piraju&city=true"),
    });
    assert.deepEqual(cities, [
      { label: "Piraju - SP", lat: -23.2, lon: -49.3 },
    ]);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
