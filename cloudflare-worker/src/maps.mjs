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
  const states = {
    acre: "AC",
    alagoas: "AL",
    amapá: "AP",
    amazonas: "AM",
    bahia: "BA",
    ceará: "CE",
    "distrito federal": "DF",
    "espírito santo": "ES",
    goiás: "GO",
    maranhão: "MA",
    "mato grosso": "MT",
    "mato grosso do sul": "MS",
    "minas gerais": "MG",
    pará: "PA",
    paraíba: "PB",
    paraná: "PR",
    pernambuco: "PE",
    piauí: "PI",
    "rio de janeiro": "RJ",
    "rio grande do norte": "RN",
    "rio grande do sul": "RS",
    rondônia: "RO",
    roraima: "RR",
    "santa catarina": "SC",
    "são paulo": "SP",
    sergipe: "SE",
    tocantins: "TO",
  };

  /** Normaliza uma cidade do Nominatim para o formato curto Município - UF. */
  function cityPlace(place) {
    const address = place.address ?? {};
    const city =
      address.city ??
      address.town ??
      address.village ??
      address.municipality ??
      place.name ??
      String(place.display_name ?? "").split(",")[0];
    const stateCode = Object.entries(address)
      .find(([key]) => key.toLowerCase().startsWith("iso3166-2"))?.[1]
      ?.split("-")
      .at(-1);
    const uf = stateCode ?? states[String(address.state ?? "").toLowerCase()];
    return {
      label: uf ? `${city} - ${uf}` : city,
      lat: Number(place.lat),
      lon: Number(place.lon),
    };
  }
  /** Faz uma chamada ao provedor de mapas com prazo e mensagem segura. */
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
    /** Pesquisa endereços, respeitando limite do Nominatim e cache local. */
    async search(query, { citiesOnly = false } = {}) {
      const key = `${citiesOnly ? "city:" : ""}${query.toLowerCase()}`;
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
          addressdetails: "1",
          ...(citiesOnly ? { featureType: "city" } : {}),
        });
        const source = await get(url);
        const data = citiesOnly
          ? [
              ...new Map(
                source.map((place) => {
                  const city = cityPlace(place);
                  return [city.label.toLowerCase(), city];
                }),
              ).values(),
            ]
          : source.map((place) => ({
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
    /** Resolve um CEP brasileiro e geocodifica o endereço para o cálculo da rota. */
    async postalCode(value) {
      const cep = String(value ?? "").replace(/\D/g, "");
      ensure(/^\d{8}$/.test(cep), "Informe um CEP com 8 dígitos.");
      const postal = await get(`https://viacep.com.br/ws/${cep}/json/`);
      ensure(!postal.erro, "CEP não encontrado.", 404);
      ensure(postal.localidade && postal.uf, "CEP sem cidade ou estado.", 422);
      const address = [
        postal.logradouro,
        postal.bairro,
        postal.localidade,
        postal.uf,
        "Brasil",
      ]
        .filter(Boolean)
        .join(", ");
      const places = await this.search(address);
      ensure(
        places.length,
        "Não foi possível localizar este CEP no mapa.",
        422,
      );
      return {
        ...places[0],
        label: [
          postal.logradouro || "CEP sem logradouro",
          postal.bairro,
          `${postal.localidade} - ${postal.uf}`,
          `CEP ${cep.substring(0, 5)}-${cep.substring(5)}`,
        ]
          .filter(Boolean)
          .join(", "),
        cep,
      };
    },
    /** Calcula uma rota de carro ou devolve a rota controlada do modo demo. */
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
