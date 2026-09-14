import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomBytes } from 'node:crypto';
import { id, hashPassword, verifyPassword, publicUser, signToken, verifyToken } from './auth.mjs';
import { AppError, ensure, text, number, serviceInput, vehicleInput } from './validation.mjs';
import { createMaps, distance, demoPlaces } from './maps.mjs';
import { createPayments } from './payments.mjs';

const activeStatuses = ['aguardando_prestador', 'pagamento_pendente', 'agendado', 'a_caminho', 'em_andamento'];
const now = () => new Date().toISOString();
const parsed = row => row ? { ...row, data: JSON.parse(row.data) } : null;
const projectDir = resolve(fileURLToPath(new URL('../..', import.meta.url)));
export function configuration(env = process.env) {
  const demo = env.DEMO_MODE !== 'false';
  ensure(demo || (env.JWT_SECRET?.length >= 32 && env.DATABASE_URL), 'Modo real exige DATABASE_URL e JWT_SECRET de pelo menos 32 caracteres.');
  return { demo, secret: env.JWT_SECRET || randomBytes(48).toString('hex'),
    origins: (env.ALLOWED_ORIGINS || 'http://localhost:8080,http://127.0.0.1:8080,http://localhost:3000,http://127.0.0.1:3000').split(','),
    nominatimUrl: env.NOMINATIM_URL || 'https://nominatim.openstreetmap.org', osrmUrl: env.OSRM_URL || 'https://router.project-osrm.org',
    mapsUserAgent: env.MAPS_USER_AGENT || 'LevaAi-AcademicMVP/0.1', mpToken: env.MERCADO_PAGO_ACCESS_TOKEN,
    staticDir: env.STATIC_DIR || resolve(projectDir, 'frontEnd/leva_ai/build/web'),
  };
}

export async function seed(db) {
  if ((await db.query('SELECT id FROM users LIMIT 1')).length) return;
  const password = await hashPassword('LevaAi@123');
  await db.transaction(async () => {
    for (const u of [
      ['demo-cliente', 'Mariana Silva', 'cliente@levaai.demo', 'cliente'],
      ['demo-prestador', 'Carlos Transportes', 'prestador@levaai.demo', 'prestador'],
      ['demo-prestador-2', 'Mudanças Horizonte', 'horizonte@levaai.demo', 'prestador'],
    ]) await db.query('INSERT INTO users(id,name,email,password_hash,role,phone,created_at) VALUES($1,$2,$3,$4,$5,$6,$7)', [u[0], u[1], u[2], password, u[3], '(11) 99999-0000', now()]);
    const sample = [
      ['demo-van', 'demo-prestador', 'Fiat Ducato', 'Van', 1500, 12, 450, 2, 8000],
      ['demo-fiorino', 'demo-prestador', 'Fiat Fiorino', 'Utilitário', 650, 3.3, 350, 1, 7000],
      ['demo-truck', 'demo-prestador-2', 'Mercedes-Benz Accelo', 'Caminhão 3/4', 3000, 24, 650, 3, 9000],
    ];
    for (const v of sample) await db.query('INSERT INTO vehicles(id,provider_id,data) VALUES($1,$2,$3)', [v[0], v[1], JSON.stringify({ model: v[2], type: v[3], capacityKg: v[4], volumeM3: v[5], pricePerKmCents: v[6], helpers: v[7], helperPriceCents: v[8], base: demoPlaces[0], radiusKm: 60, active: true })]);
  });
}

export function createApp(db, config, overrides = {}) {
  const maps = overrides.maps || createMaps(config), payments = overrides.payments || createPayments(config);
  const rateBuckets = new Map();
  const one = async (sql, args) => (await db.query(sql, args))[0];
  async function userFrom(req) {
    const claims = verifyToken((req.headers.authorization || '').replace(/^Bearer /, ''), config.secret);
    ensure(claims, 'Entre na sua conta para continuar.', 401);
    const session = await one('SELECT * FROM sessions WHERE id=$1 AND user_id=$2', [claims.jti, claims.sub]);
    ensure(session && session.expires_at > now(), 'Sua sessão expirou. Entre novamente.', 401);
    const user = await one('SELECT * FROM users WHERE id=$1', [claims.sub]);
    ensure(user, 'Conta não encontrada.', 401);
    return { ...user, sessionId: claims.jti };
  }
  function role(user, expected) { ensure(user.role === expected, 'Seu perfil não pode realizar esta ação.', 403); }
  async function session(user) {
    const sid = id();
    await db.query('INSERT INTO sessions(id,user_id,expires_at) VALUES($1,$2,$3)', [sid, user.id, new Date(Date.now() + 28800000).toISOString()]);
    return { user: publicUser(user), token: signToken(user, config.secret, sid) };
  }
  async function bookingFor(user, bookingId) {
    const booking = parsed(await one('SELECT * FROM bookings WHERE id=$1', [bookingId]));
    ensure(booking && [booking.client_id, booking.provider_id].includes(user.id), 'Solicitação não encontrada.', 404);
    return booking;
  }
  async function change(booking, status, user) {
    await db.query('UPDATE bookings SET status=$1 WHERE id=$2', [status, booking.id]);
    await db.query('INSERT INTO history(id,booking_id,actor_id,status,created_at) VALUES($1,$2,$3,$4,$5)', [id(), booking.id, user.id, status, now()]);
    booking.status = status;
  }
  async function compatible(vehicle, input) {
    const provider = await one('SELECT * FROM users WHERE id=$1', [vehicle.provider_id]);
    const v = vehicle.data;
    if (!provider?.available || !vehicle.active || v.capacityKg < input.weightKg || v.volumeM3 < input.volumeM3 || v.helpers < input.helpers || distance(v.base, input.origin) > v.radiusKm) return false;
    const rows = await db.query('SELECT * FROM bookings WHERE vehicle_id=$1 AND service_date=$2', [vehicle.id, input.date]);
    // MVP: cada veículo atende uma reserva por dia; equipe de ajudantes pertence ao veículo.
    return !rows.some(r => activeStatuses.includes(r.status));
  }
  async function details(booking) {
    const payment = parsed(await one('SELECT * FROM payments WHERE booking_id=$1', [booking.id]));
    const review = await one('SELECT * FROM reviews WHERE booking_id=$1', [booking.id]);
    const history = await db.query('SELECT status,created_at FROM history WHERE booking_id=$1 ORDER BY created_at,id', [booking.id]);
    const client = await one('SELECT name,phone FROM users WHERE id=$1', [booking.client_id]);
    const provider = await one('SELECT name,phone FROM users WHERE id=$1', [booking.provider_id]);
    return { ...booking, payment, review: review || null, history, client, provider };
  }
  async function route(req, path, b, user) {
    const method = req.method;
    if (method === 'GET' && path === '/api/config') return { demo: config.demo, demoPlaces: config.demo ? demoPlaces : [], paymentMode: config.demo ? 'demo' : 'mercado_pago' };
    if (method === 'GET' && path === '/api/health') return { status: 'ok' };
    if (method === 'POST' && path === '/api/auth/register') {
      const name = text(b.name, 'Nome', 2, 150), email = text(b.email, 'E-mail', 5, 150).toLowerCase();
      ensure(/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email), 'Informe um e-mail válido.');
      ensure(['cliente', 'prestador'].includes(b.role), 'Escolha seu perfil.');
      const password = text(b.password, 'Senha', 8, 128), phone = text(b.phone, 'Telefone', 10, 20);
      ensure(!await one('SELECT id FROM users WHERE email=$1', [email]), 'Este e-mail já está cadastrado.', 409);
      const u = { id: id(), name, email, role: b.role, phone, available: 1 };
      await db.query('INSERT INTO users(id,name,email,password_hash,role,phone,created_at) VALUES($1,$2,$3,$4,$5,$6,$7)', [u.id, name, email, await hashPassword(password), b.role, phone, now()]);
      return session(u);
    }
    if (method === 'POST' && path === '/api/auth/login') {
      const email = text(b.email, 'E-mail', 3, 150).toLowerCase(), password = text(b.password, 'Senha', 1, 128);
      const u = await one('SELECT * FROM users WHERE email=$1', [email]);
      // Derivação também para conta inexistente, reduzindo diferença de tempo.
      const valid = await verifyPassword(password, u?.password_hash || `${'0'.repeat(32)}:${'0'.repeat(128)}`);
      ensure(u && valid, 'E-mail ou senha incorretos.', 401);
      return session(u);
    }
    if (method === 'GET' && path === '/api/me') return publicUser(user);
    if (method === 'POST' && path === '/api/auth/logout') {
      await db.query('DELETE FROM sessions WHERE id=$1', [user.sessionId]); return { ok: true };
    }
    if (method === 'PATCH' && path === '/api/me/availability') {
      role(user, 'prestador'); ensure(typeof b.available === 'boolean', 'Disponibilidade inválida.');
      await db.query('UPDATE users SET available=$1 WHERE id=$2', [b.available ? 1 : 0, user.id]);
      return publicUser({ ...user, available: b.available });
    }
    if (method === 'GET' && path === '/api/maps/search') {
      const query = text(new URL(req.url, 'http://localhost').searchParams.get('q'), 'Endereço', 4, 200);
      return maps.search(query);
    }
    if (method === 'GET' && path === '/api/vehicles') {
      role(user, 'prestador'); return (await db.query('SELECT * FROM vehicles WHERE provider_id=$1', [user.id])).map(parsed);
    }
    if (method === 'POST' && path === '/api/vehicles') {
      role(user, 'prestador'); const data = vehicleInput(b), vehicleId = id();
      await db.query('INSERT INTO vehicles(id,provider_id,active,data) VALUES($1,$2,$3,$4)', [vehicleId, user.id, data.active ? 1 : 0, JSON.stringify(data)]);
      return { id: vehicleId, provider_id: user.id, active: data.active ? 1 : 0, data };
    }
    const vehicleMatch = path.match(/^\/api\/vehicles\/([^/]+)$/);
    if (method === 'PUT' && vehicleMatch) {
      role(user, 'prestador'); ensure(await one('SELECT id FROM vehicles WHERE id=$1 AND provider_id=$2', [vehicleMatch[1], user.id]), 'Veículo não encontrado.', 404);
      const data = vehicleInput(b);
      await db.query('UPDATE vehicles SET active=$1,data=$2 WHERE id=$3', [data.active ? 1 : 0, JSON.stringify(data), vehicleMatch[1]]);
      return { ok: true };
    }
    if (method === 'POST' && path === '/api/quotes') {
      role(user, 'cliente'); const input = serviceInput(b);
      const route = await maps.route(input.origin, input.destination, input.demoRoute);
      const vehicles = (await db.query('SELECT * FROM vehicles WHERE active=1')).map(parsed), quotes = [];
      for (const vehicle of vehicles) {
        if (!await compatible(vehicle, input)) continue;
        const v = vehicle.data, provider = await one('SELECT name FROM users WHERE id=$1', [vehicle.provider_id]);
        const reviews = await db.query('SELECT rating FROM reviews WHERE provider_id=$1', [vehicle.provider_id]);
        const transportCents = Math.round(route.distanceKm * v.pricePerKmCents), helpersCents = input.helpers * v.helperPriceCents;
        const data = { input, route, providerName: provider.name, providerId: vehicle.provider_id, vehicle: v,
          rating: reviews.length ? reviews.reduce((s, r) => s + r.rating, 0) / reviews.length : null, reviewCount: reviews.length,
          providerDistanceKm: Math.round(distance(v.base, input.origin) * 10) / 10,
          transportCents, helpersCents, totalCents: transportCents + helpersCents };
        const quote = { id: id(), vehicle_id: vehicle.id, expires_at: new Date(Date.now() + 900000).toISOString(), data };
        await db.query('INSERT INTO quotes(id,client_id,vehicle_id,expires_at,data) VALUES($1,$2,$3,$4,$5)', [quote.id, user.id, vehicle.id, quote.expires_at, JSON.stringify(data)]);
        quotes.push(quote);
      }
      return { route, quotes: quotes.sort((a, b) => a.data.totalCents - b.data.totalCents) };
    }
    if (method === 'POST' && path === '/api/bookings') {
      role(user, 'cliente');
      const quote = parsed(await one('SELECT * FROM quotes WHERE id=$1 AND client_id=$2', [text(b.quoteId, 'Orçamento'), user.id]));
      ensure(quote, 'Orçamento não encontrado.', 404);
      const existing = parsed(await one('SELECT * FROM bookings WHERE quote_id=$1', [quote.id]));
      if (existing) return details(existing);
      ensure(quote.expires_at > now(), 'O orçamento expirou. Faça uma nova busca.', 409);
      serviceInput(quote.data.input);
      const vehicle = parsed(await one('SELECT * FROM vehicles WHERE id=$1', [quote.vehicle_id]));
      ensure(vehicle && await compatible(vehicle, quote.data.input), 'O veículo não está mais disponível para esta solicitação.', 409);
      ensure(vehicle.data.pricePerKmCents === quote.data.vehicle.pricePerKmCents && vehicle.data.helperPriceCents === quote.data.vehicle.helperPriceCents, 'O preço foi atualizado. Faça uma nova cotação.', 409);
      const booking = { id: id(), quote_id: quote.id, client_id: user.id, provider_id: vehicle.provider_id, vehicle_id: vehicle.id,
        service_date: quote.data.input.date, status: 'aguardando_prestador', data: quote.data, created_at: now() };
      await db.query('INSERT INTO bookings(id,quote_id,client_id,provider_id,vehicle_id,service_date,status,data,created_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)', [booking.id, quote.id, user.id, vehicle.provider_id, vehicle.id, booking.service_date, booking.status, JSON.stringify(booking.data), booking.created_at]);
      await change(booking, booking.status, user); return details(booking);
    }
    if (method === 'GET' && path === '/api/bookings') {
      const field = user.role === 'cliente' ? 'client_id' : 'provider_id';
      const rows = await db.query(`SELECT * FROM bookings WHERE ${field}=$1 ORDER BY created_at DESC`, [user.id]);
      return Promise.all(rows.map(row => details(parsed(row))));
    }
    const match = path.match(/^\/api\/bookings\/([^/]+)(?:\/(status|payment|payment-check|demo-pay|review))?$/);
    if (match) {
      const booking = await bookingFor(user, match[1]), action = match[2];
      if (method === 'GET' && !action) return details(booking);
      if (method === 'POST' && action === 'status') {
        const allowed = user.role === 'prestador' ? {
          aguardando_prestador: ['pagamento_pendente', 'recusado_prestador'],
          agendado: ['a_caminho'], a_caminho: ['em_andamento'], em_andamento: ['concluido'],
        } : { aguardando_prestador: ['cancelado_cliente'], pagamento_pendente: ['cancelado_cliente'] };
        ensure(allowed[booking.status]?.includes(b.status), 'Esta mudança de status não é permitida.', 409);
        if (b.status === 'cancelado_cliente') ensure(!await one('SELECT id FROM payments WHERE booking_id=$1', [booking.id]), 'O Pix já foi emitido. O cancelamento precisa ser conciliado pelo atendimento.', 409);
        await change(booking, b.status, user); return details(booking);
      }
      if (method === 'POST' && action === 'payment') {
        role(user, 'cliente'); ensure(booking.status === 'pagamento_pendente', 'Aguarde o aceite do prestador para pagar.', 409);
        let payment = await one('SELECT * FROM payments WHERE booking_id=$1', [booking.id]);
        if (!payment) {
          const data = await payments.create(booking, user);
          await db.query('INSERT INTO payments(id,booking_id,amount_cents,status,gateway,external_id,data) VALUES($1,$2,$3,$4,$5,$6,$7)', [id(), booking.id, booking.data.totalCents, 'pendente', data.gateway, data.externalId, JSON.stringify(data)]);
        }
        return details(booking);
      }
      if (method === 'POST' && ['payment-check', 'demo-pay'].includes(action)) {
        role(user, 'cliente');
        const payment = await one('SELECT * FROM payments WHERE booking_id=$1', [booking.id]);
        ensure(payment, 'Gere o Pix primeiro.', 409);
        if (action === 'demo-pay') ensure(config.demo && payment.gateway === 'demo', 'Confirmação demonstrativa desativada.', 403);
        if (payment.status === 'aprovado') return details(booking);
        ensure(booking.status === 'pagamento_pendente', 'O pagamento não pode ser confirmado neste status.', 409);
        const status = action === 'demo-pay' ? 'aprovado' : await payments.check(payment, booking);
        await db.query('UPDATE payments SET status=$1 WHERE id=$2', [status, payment.id]);
        if (status === 'aprovado') await change(booking, 'agendado', user);
        if (status === 'recusado') await change(booking, 'pagamento_recusado', user);
        return details(booking);
      }
      if (method === 'POST' && action === 'review') {
        role(user, 'cliente'); ensure(booking.status === 'concluido', 'Você pode avaliar depois da conclusão, uma única vez.', 409);
        const rating = number(b.rating, 'Nota', 1, 5, true), comment = text(b.comment || '', 'Comentário', 0, 1000);
        await db.query('INSERT INTO reviews(id,booking_id,client_id,provider_id,rating,comment,created_at) VALUES($1,$2,$3,$4,$5,$6,$7)', [id(), booking.id, user.id, booking.provider_id, rating, comment, now()]);
        await change(booking, 'avaliado', user); return details(booking);
      }
    }
    throw new AppError('Recurso não encontrado.', 404);
  }

  return createServer(async (req, res) => {
    const requestId = id();
    res.setHeader('X-Request-Id', requestId);
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    res.setHeader('X-Frame-Options', 'DENY');
    const path = new URL(req.url, 'http://localhost').pathname;
    try {
      const origin = req.headers.origin;
      if (origin) {
        const forwardedProtocol = String(req.headers['x-forwarded-proto'] || (req.socket.encrypted ? 'https' : 'http')).split(',')[0].trim();
        const forwardedHost = String(req.headers['x-forwarded-host'] || req.headers.host || '').split(',')[0].trim();
        const sameOrigin = origin === `${forwardedProtocol}://${forwardedHost}`;
        ensure(config.origins.includes(origin) || sameOrigin, 'Origem não autorizada.', 403);
        res.setHeader('Access-Control-Allow-Origin', origin);
        res.setHeader('Vary', 'Origin');
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, OPTIONS');
      }
      if (req.method === 'OPTIONS') { res.writeHead(204); return res.end(); }
      if (!path.startsWith('/api/')) {
        ensure(req.method === 'GET', 'Método não permitido.', 405);
        let file = resolve(config.staticDir, `.${decodeURIComponent(path === '/' ? '/index.html' : path)}`);
        ensure(file.startsWith(config.staticDir + sep), 'Caminho inválido.', 403);
        try { ensure((await stat(file)).isFile(), 'Arquivo não encontrado.', 404); } catch { throw new AppError('Compile o Flutter Web para abrir a aplicação. Consulte o README.', 404); }
        const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.ttf': 'font/ttf', '.otf': 'font/otf', '.ico': 'image/x-icon' };
        res.setHeader('Content-Type', mime[extname(file)] || 'application/octet-stream');
        res.setHeader('Cache-Control', 'no-cache');
        return res.end(await readFile(file));
      }
      res.setHeader('Cache-Control', 'no-store');
      const authRoute = path.startsWith('/api/auth/') && path !== '/api/auth/logout';
      const key = `${req.socket.remoteAddress}:${authRoute ? 'auth' : 'api'}`;
      const bucket = rateBuckets.get(key) || { count: 0, until: Date.now() + 60000 };
      if (bucket.until < Date.now()) { bucket.count = 0; bucket.until = Date.now() + 60000; }
      bucket.count++; rateBuckets.set(key, bucket);
      if (rateBuckets.size > 2000) for (const [k, v] of rateBuckets) if (v.until < Date.now()) rateBuckets.delete(k);
      ensure(bucket.count <= (authRoute ? 20 : 180), 'Muitas tentativas. Aguarde um minuto.', 429);
      let body = '', bodyBytes = 0;
      for await (const chunk of req) { bodyBytes += chunk.length; ensure(bodyBytes <= 32768, 'Solicitação muito grande.', 413); body += chunk; }
      let b = {};
      if (body) { try { b = JSON.parse(body); } catch { throw new AppError('JSON inválido.'); } }
      ensure(b !== null && typeof b === 'object' && !Array.isArray(b), 'Corpo da solicitação inválido.');
      const isPublic = ['/api/auth/login', '/api/auth/register', '/api/config', '/api/health'].includes(path);
      // Serializa leituras e escritas: nenhuma requisição observa transações incompletas.
      const value = await db.transaction(async () => route(req, path, b, isPublic ? null : await userFrom(req)));
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' }); res.end(JSON.stringify(value));
    } catch (error) {
      const status = error.status || (['23505', 'SQLITE_CONSTRAINT_UNIQUE'].includes(error.code) || error.message?.includes('UNIQUE constraint') ? 409 : 500);
      if (status === 500) console.error(JSON.stringify({ requestId, message: 'Falha interna', code: error.code || error.name }));
      res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ error: status === 500 ? 'Não foi possível concluir. Tente novamente.' : status === 409 && !error.status ? 'Registro já existente ou reserva indisponível.' : error.message, requestId }));
    }
  });
}
