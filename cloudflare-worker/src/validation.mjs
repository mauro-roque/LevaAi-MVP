/** Erro esperado da aplicação, convertido em resposta HTTP segura. */
export class AppError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}
/** Interrompe a requisição quando uma pré-condição não é atendida. */
export function ensure(value, message, status = 400) {
  if (!value) throw new AppError(message, status);
}
/** Valida e normaliza campos de texto recebidos pela API. */
export function text(value, label, min = 1, max = 200) {
  ensure(
    typeof value === "string" &&
      value.trim().length >= min &&
      value.trim().length <= max,
    `${label}: informe entre ${min} e ${max} caracteres.`,
  );
  return value.trim();
}
/** Aceita somente números dentro dos limites do domínio do MVP. */
export function number(value, label, min, max, integer = false) {
  ensure(
    typeof value === "number" &&
      Number.isFinite(value) &&
      value >= min &&
      value <= max &&
      (!integer || Number.isInteger(value)),
    `${label}: valor inválido (${min} a ${max}).`,
  );
  return value;
}
/** Valida um endereço geocodificado usado na origem, destino ou base. */
export function point(value) {
  ensure(value && typeof value === "object", "Selecione um endereço na busca.");
  return {
    label: text(value.label, "Endereço", 3, 500),
    lat: number(value.lat, "Latitude", -90, 90),
    lon: number(value.lon, "Longitude", -180, 180),
  };
}
/** Normaliza os dados de uma solicitação antes de persistir a cotação. */
export function serviceInput(b) {
  const date = text(b.date, "Data", 10, 10),
    today = new Intl.DateTimeFormat("en-CA", {
      timeZone: "America/Sao_Paulo",
    }).format(new Date());
  ensure(
    /^\d{4}-\d{2}-\d{2}$/.test(date) &&
      !Number.isNaN(Date.parse(date)) &&
      new Date(date).toISOString().slice(0, 10) === date &&
      date >= today,
    "Escolha uma data válida a partir de hoje.",
  );
  ensure(["frete", "mudanca"].includes(b.type), "Tipo de serviço inválido.");
  return {
    origin: point(b.origin),
    destination: point(b.destination),
    date,
    type: b.type,
    items: text(b.items, "Itens e quantidades", 3, 1000),
    weightKg: number(b.weightKg, "Peso (kg)", 1, 30000),
    volumeM3: number(b.volumeM3, "Volume (m³)", 0.1, 150),
    helpers: number(b.helpers, "Ajudantes", 0, 6, true),
    demoRoute: b.demoRoute === true,
  };
}
/** Normaliza os dados de um veículo cadastrado pelo prestador. */
export function vehicleInput(b) {
  return {
    model: text(b.model, "Modelo", 2, 80),
    type: text(b.type, "Tipo", 2, 40),
    capacityKg: number(b.capacityKg, "Capacidade (kg)", 1, 30000),
    volumeM3: number(b.volumeM3, "Volume (m³)", 0.1, 150),
    pricePerKmCents: number(
      b.pricePerKmCents,
      "Preço por km (centavos)",
      1,
      100000,
      true,
    ),
    helpers: number(b.helpers, "Ajudantes", 0, 6, true),
    helperPriceCents: number(
      b.helperPriceCents,
      "Preço do ajudante",
      0,
      100000,
      true,
    ),
    base: point(b.base),
    radiusKm: number(b.radiusKm, "Raio de atendimento (km)", 1, 500),
    active: b.active !== false,
  };
}
