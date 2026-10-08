// Заливка демонстрационных данных автосервиса в PocketBase.
//
// Запуск (сервер должен быть запущен):  node seed.mjs
//          заново, с очисткой:           node seed.mjs --reset
// Нужен Node.js 18 или новее — fetch встроен.
//
// Скрипт входит суперпользователем, поэтому правила доступа ему не мешают,
// а серверные хуки работают как обычно: окончание и стоимость записей
// на обслуживание считает сервер.

import { readFileSync } from 'node:fs';

const BASE = process.env.API_URL ?? 'http://127.0.0.1:8090';
const SUPERUSER = process.env.PB_SUPERUSER ?? 'admin@autoservice.local';
const SUPERUSER_PASSWORD = process.env.PB_SUPERUSER_PASSWORD ?? 'Autoservice2026';
const RESET = process.argv.includes('--reset');

const data = JSON.parse(readFileSync(new URL('./seed-data.json', import.meta.url), 'utf8'));

let token = '';

async function api(method, path, body) {
  const response = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json', Authorization: token },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  const json = text ? JSON.parse(text) : null;
  if (!response.ok) {
    const err = new Error(`${method} ${path} → ${response.status}: ${json?.message} ${JSON.stringify(json?.data ?? {})}`);
    err.status = response.status;
    throw err;
  }
  return json;
}

const create = (collection, record) => api('POST', `/api/collections/${collection}/records`, record);

async function listAll(collection) {
  const items = [];
  for (let page = 1; ; page++) {
    const r = await api('GET', `/api/collections/${collection}/records?perPage=500&page=${page}&fields=id`);
    items.push(...r.items);
    if (page >= r.totalPages) return items;
  }
}

/** Дата «2019-03-14» → «2019-03-14 00:00:00.000Z». */
const day = (s) => (s ? `${s.slice(0, 10)} 00:00:00.000Z` : '');

// Порядок важен: сначала удаляется то, что ссылается на другие записи.
const ORDER = [
  'appointments',
  'cars',
  'club_cards',
  'users',
  'clients',
  'services',
  'service_categories',
  'car_models',
  'brands',
  'mechanics',
];

async function reset() {
  for (const collection of ORDER) {
    const items = await listAll(collection);
    for (const { id } of items) await api('DELETE', `/api/collections/${collection}/records/${id}`);
    if (items.length) console.log(`  удалено ${collection}: ${items.length}`);
  }
}

// Простой повторяемый генератор случайных чисел — данные одинаковы при каждой заливке.
let seed = 20261008;
const rand = () => ((seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648);
const pick = (list) => list[Math.floor(rand() * list.length)];

async function main() {
  token = (await api('POST', '/api/collections/_superusers/auth-with-password', {
    identity: SUPERUSER,
    password: SUPERUSER_PASSWORD,
  })).token;

  const existing = await api('GET', '/api/collections/brands/records?perPage=1');
  if (existing.totalItems > 0) {
    if (!RESET) {
      console.log('Данные уже залиты. Чтобы залить заново: node seed.mjs --reset');
      return;
    }
    console.log('Очистка…');
    await reset();
  }

  const categoryId = {};
  for (const c of data.categories) {
    categoryId[c.code] = (await create('service_categories', { name: c.name })).id;
  }

  const brandId = {};
  const modelId = {}; // «Lada|Granta» → id
  for (const b of data.brands) {
    brandId[b.id] = (await create('brands', { name: b.name, country: b.country })).id;
    for (const m of b.models) {
      modelId[`${b.id}|${m}`] = (await create('car_models', { brand: brandId[b.id], name: m })).id;
    }
  }

  const mechanicId = {};
  for (const m of data.mechanics) {
    mechanicId[m.id] = (await create('mechanics', {
      last_name: m.lastName,
      first_name: m.firstName,
      middle_name: m.middleName,
      phone: m.phone,
      grade: m.grade,
      experience: m.experience,
      hired_at: day(m.hiredAt),
    })).id;
  }

  const serviceId = {};
  const serviceDuration = {};
  for (const s of data.services) {
    serviceId[s.id] = (await create('services', {
      name: s.name,
      category: categoryId[s.category],
      price: s.price,
      duration: s.duration,
    })).id;
    serviceDuration[s.id] = s.duration;
  }

  const clientId = {};
  for (const c of data.clients) {
    clientId[c.id] = (await create('clients', {
      last_name: c.lastName,
      first_name: c.firstName,
      middle_name: c.middleName,
      phone: c.phone,
      email: c.email,
      discount: c.discount,
      registered_at: day(c.registeredAt),
    })).id;
    if (c.card) {
      await create('club_cards', {
        client: clientId[c.id],
        number: c.card.number,
        level: c.card.level,
        issued_at: day(c.card.issuedAt),
        expires_at: day(c.card.expiresAt),
        bonus_points: c.card.bonusPoints ?? 0,
      });
    }
  }

  const cars = [];
  for (const car of data.cars) {
    const record = await create('cars', {
      plate: car.plate,
      vin: car.vin,
      model: modelId[`${car.brandId}|${car.model}`],
      year: car.year,
      mileage: car.mileage,
      fuel: car.fuel,
      client: clientId[car.clientId],
      mechanics: car.mechanicIds.map((id) => mechanicId[id]),
      deleted_at: car.deletedAt ? day(car.deletedAt) : '',
    });
    if (!car.deletedAt) cars.push({ ...car, pbId: record.id });
  }

  // Учётные записи для проверки ролей
  const users = [
    { username: 'admin', password: 'Admin#2026', role: 'admin', last_name: 'Казанцев', first_name: 'Виктор', email: 'admin@autoservice.local' },
    { username: 'master', password: 'Master#2026', role: 'mechanic', last_name: 'Громов', first_name: 'Виктор', email: 'master@autoservice.local', mechanic: mechanicId[1] },
    { username: 'client', password: 'Client#2026', role: 'client', last_name: 'Иванов', first_name: 'Сергей', email: 's.ivanov@mail.ru', client: clientId[1] },
  ];
  for (const u of users) {
    await create('users', { ...u, passwordConfirm: u.password, emailVisibility: false });
  }

  // Записи на обслуживание: две недели вокруг сегодняшнего дня, по будням.
  // Время — московское (UTC+3); у каждого мастера записи идут подряд, не пересекаясь.
  const now = new Date();
  const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  let created = 0;
  for (let d = -7; d <= 7; d++) {
    const date = new Date(today + d * 86400000);
    const weekday = date.getUTCDay();
    if (weekday === 0 || weekday === 6) continue;
    const cursor = {}; // мастер → минуты от полуночи, когда он освободится
    for (let k = 0; k < 3; k++) {
      const car = pick(cars);
      const mechanic = pick(car.mechanicIds);
      // Одна-две услуги, всего не больше пяти часов
      const services = [];
      let minutes = 0;
      for (const s of [pick(data.services), pick(data.services)]) {
        if (services.includes(s.id) || minutes + s.duration > 300) continue;
        services.push(s.id);
        minutes += s.duration;
      }
      if (services.length === 0) continue;
      const startMin = Math.ceil((cursor[mechanic] ?? 9 * 60) / 30) * 30;
      if (startMin + minutes > 20 * 60) continue;
      cursor[mechanic] = startMin + minutes + 30;
      const start = new Date(date.getTime() + (startMin - 3 * 60) * 60000);
      const status =
        d < 0 ? (rand() < 0.15 ? 'cancelled' : 'done') : d === 0 ? 'in_progress' : 'planned';
      await create('appointments', {
        car: car.pbId,
        mechanic: mechanicId[mechanic],
        services: services.map((id) => serviceId[id]),
        starts_at: start.toISOString().replace('T', ' '),
        status,
        comment: '',
      });
      created++;
    }
  }

  console.log(
    `Готово: категорий ${data.categories.length}, марок ${data.brands.length}, ` +
      `моделей ${Object.keys(modelId).length}, мастеров ${data.mechanics.length}, ` +
      `услуг ${data.services.length}, клиентов ${data.clients.length}, ` +
      `автомобилей ${data.cars.length}, пользователей ${users.length}, записей ${created}.`,
  );
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
