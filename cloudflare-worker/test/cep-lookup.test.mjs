import test from "node:test";
import assert from "node:assert/strict";
import { createApi } from "../src/normalized-api.mjs";

/** Valida a confirmação visual e o ponto geocodificado devolvidos para um CEP. */
test("consulta CEP devolve endereço confirmado e coordenadas", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url) => {
    const request = String(url);
    if (request.includes("viacep.com.br"))
      return new Response(
        JSON.stringify({
          cep: "18800-000",
          logradouro: "Rua Exemplo",
          bairro: "Centro",
          localidade: "Piraju",
          uf: "SP",
        }),
        { status: 200 },
      );
    assert.match(request, /nominatim\.test/);
    return new Response(
      JSON.stringify([
        {
          display_name: "Rua Exemplo, Piraju, São Paulo",
          lat: "-23.2",
          lon: "-49.3",
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
    const address = await api.handle({
      method: "GET",
      path: "/api/maps/cep",
      url: new URL("https://app.test/api/maps/cep?cep=18800000"),
    });
    assert.deepEqual(address, {
      label: "Rua Exemplo, Centro, Piraju - SP, CEP 18800-000",
      lat: -23.2,
      lon: -49.3,
      cep: "18800000",
    });
  } finally {
    globalThis.fetch = originalFetch;
  }
});
