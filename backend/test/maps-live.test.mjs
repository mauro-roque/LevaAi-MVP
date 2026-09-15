import { test } from "node:test";
import assert from "node:assert/strict";
import { createMaps, demoPlaces } from "../src/maps.mjs";
import { configuration } from "../src/app.mjs";

test(
  "mapas reais: busca pública e rota OSRM",
  { skip: process.env.RUN_MAPS_TEST !== "true" },
  async () => {
    const maps = createMaps(configuration());
    const places = await maps.search("Praça da Sé, São Paulo, Brasil");
    assert(places.length > 0);
    const route = await maps.route(demoPlaces[0], demoPlaces[1], false);
    assert.equal(route.demo, false);
    assert(
      route.distanceKm > 0 &&
        route.durationMinutes > 0 &&
        route.coordinates.length > 2,
    );
    console.log(
      `Rota real consultada: ${route.distanceKm} km, ${route.durationMinutes} minutos.`,
    );
  },
);
