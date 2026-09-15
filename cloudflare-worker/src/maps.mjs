import { AppError, ensure } from "./validation.mjs";
/** Endereços estáveis para apresentar o MVP enquanto o geocodificador não responde. */
export const demoPlaces = [
  { label: "Praça da Sé, São Paulo — SP", lat: -23.5505, lon: -46.6333 },
  { label: "Parque Ibirapuera, São Paulo — SP", lat: -23.5874, lon: -46.6576 },
  { label: "Terminal Tietê, São Paulo — SP", lat: -23.5162, lon: -46.6252 },
];
/** Calcula a distância aproximada entre dois pontos geográficos, em quilômetros. */
export function distance(a, b) {
  const rad = (value) => (value * Math.PI) / 180,
    h =
      Math.sin(rad(b.lat - a.lat) / 2) ** 2 +
      Math.cos(rad(a.lat)) *
        Math.cos(rad(b.lat)) *
        Math.sin(rad(b.lon - a.lon) / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}
/** Cria adaptadores de busca e rota com alternativas seguras para o modo demo. */
export function createMaps(config) {
  const cache = new Map();
  let lastCall = 0,
    queue = Promise.resolve();
  async function get(url) {
    try {
      const response = await fetch(url, {
        headers: {
          "User-Agent": config.mapsUserAgent,
          "Accept-Language": "pt-BR",
        },
        signal: AbortSignal.timeout(15000),
      });
      if (!response.ok) throw new Error("maps");
      return response.json();
    } catch {
      throw new AppError(
        "O serviço de mapas está indisponível. Tente novamente em instantes.",
        503,
      );
    }
  }
  return {
    async search(query) {
      const key = query.toLowerCase();
      if (cache.has(key)) return cache.get(key);
      const operation = queue.then(async () => {
        if (cache.has(key)) return cache.get(key);
        await new Promise((done) =>
          setTimeout(done, Math.max(0, 1100 - (Date.now() - lastCall))),
        );
        lastCall = Date.now();
        const url = new URL("/search", config.nominatimUrl);
        url.search = new URLSearchParams({
          q: query,
          format: "jsonv2",
          limit: "5",
          countrycodes: "br",
        });
        const data = (await get(url)).map((place) => ({
          label: place.display_name,
          lat: Number(place.lat),
          lon: Number(place.lon),
        }));
        if (cache.size > 500) cache.delete(cache.keys().next().value);
        cache.set(key, data);
        return data;
      });
      queue = operation.catch(() => {});
      return operation;
    },
    async route(origin, destination, demo) {
      ensure(
        distance(origin, destination) > 0.05,
        "Escolha origem e destino diferentes.",
      );
      if (demo) {
        ensure(config.demo, "Rota de demonstração desativada.");
        ensure(
          demoPlaces.some((place) => distance(place, origin) < 0.01) &&
            demoPlaces.some((place) => distance(place, destination) < 0.01),
          "Use os endereços de exemplo para a rota demonstrativa.",
        );
        return {
          distanceKm: Math.round(distance(origin, destination) * 14) / 10,
          durationMinutes: 25,
          demo: true,
          coordinates: [
            [origin.lon, origin.lat],
            [destination.lon, destination.lat],
          ],
        };
      }
      const url = new URL(
        `/route/v1/driving/${origin.lon},${origin.lat};${destination.lon},${destination.lat}`,
        config.osrmUrl,
      );
      url.search = "overview=full&geometries=geojson";
      const data = await get(url);
      ensure(
        data.code === "Ok" && data.routes?.length,
        "Não foi encontrada uma rota de carro entre os endereços.",
        422,
      );
      const route = data.routes[0];
      return {
        distanceKm: Math.ceil(route.distance / 100) / 10,
        durationMinutes: Math.ceil(route.duration / 60),
        demo: false,
        coordinates: route.geometry.coordinates,
      };
    },
  };
}
