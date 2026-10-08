/// <reference path="../pb_data/types.d.ts" />

// Общие функции хуков. Обработчики PocketBase выполняются каждый в своём
// окружении, поэтому функции подключаются внутри обработчика через require.

// Автосервис работает по московскому времени (UTC+3), с 9:00 до 20:00.
const TZ_OFFSET_MIN = 3 * 60;
const OPEN_MIN = 9 * 60;
const CLOSE_MIN = 20 * 60;

// Скидка по уровню клубной карты и общий предел скидки, %.
const CARD_DISCOUNT = { standard: 0, silver: 5, gold: 10 };
const MAX_DISCOUNT = 15;

/** Дата PocketBase «2026-10-08 10:00:00.000Z» → Date. */
function toDate(value) {
  const s = String(value || '');
  if (!s) return null;
  const d = new Date(s.replace(' ', 'T'));
  return isNaN(d.getTime()) ? null : d;
}

/** Date → строка даты PocketBase для фильтров. */
function toPb(date) {
  return date.toISOString().replace('T', ' ');
}

function hhmm(date) {
  const local = new Date(date.getTime() + TZ_OFFSET_MIN * 60000);
  const h = String(local.getUTCHours()).padStart(2, '0');
  const m = String(local.getUTCMinutes()).padStart(2, '0');
  return h + ':' + m;
}

/** Минуты от полуночи по времени автосервиса. */
function localMinutes(date) {
  const local = new Date(date.getTime() + TZ_OFFSET_MIN * 60000);
  return local.getUTCHours() * 60 + local.getUTCMinutes();
}

/** Ошибка у поля формы: 422, данные в том же виде, что у проверок PocketBase. */
function fieldError(field, message) {
  const data = {};
  data[field] = new ValidationError('validation_' + field, message);
  return new ApiError(422, message, data);
}

/**
 * Скидка по правилам автосервиса: большая из персональной скидки клиента
 * и скидки по уровню клубной карты, действующей на дату записи; не больше 15 %.
 */
function discountFor(app, clientId, startsAt) {
  const client = app.findRecordById('clients', clientId);
  const personal = client.getInt('discount');
  let card = 0;
  try {
    const c = app.findFirstRecordByFilter('club_cards', 'client = {:client}', { client: clientId });
    const issued = toDate(c.getString('issued_at'));
    const expires = toDate(c.getString('expires_at'));
    if (issued && expires && startsAt >= issued && startsAt <= expires) {
      card = CARD_DISCOUNT[c.getString('level')] || 0;
    }
  } catch (_) {
    // карты нет
  }
  const percent = Math.min(MAX_DISCOUNT, Math.max(personal, card));
  const source = percent === 0 ? 'none' : card >= personal ? 'card' : 'personal';
  return { percent: percent, source: source };
}

/**
 * Перед сохранением записи на обслуживание: окончание по нормам времени
 * услуг, проверка рабочих часов и занятости мастера, стоимость со скидкой.
 */
function prepareAppointment(app, record) {
  const serviceIds = record.getStringSlice('services');
  if (serviceIds.length === 0) throw fieldError('services', 'Выберите хотя бы одну услугу');

  const start = toDate(record.getString('starts_at'));
  if (!start) throw fieldError('starts_at', 'Укажите дату и время начала');

  let subtotal = 0;
  let duration = 0;
  for (const s of app.findRecordsByIds('services', serviceIds)) {
    subtotal += s.getInt('price');
    duration += s.getInt('duration');
  }
  const end = new Date(start.getTime() + duration * 60000);
  record.set('ends_at', toPb(end));

  const status = record.getString('status');
  const active = status !== 'cancelled' && !record.getString('deleted_at');

  if (active) {
    const from = localMinutes(start);
    if (from < OPEN_MIN || from + duration > CLOSE_MIN) {
      throw fieldError(
        'starts_at',
        'Автосервис работает с 9:00 до 20:00, работы займут ' + duration + ' мин',
      );
    }

    const busy = app.findRecordsByFilter(
      'appointments',
      'mechanic = {:mechanic} && status != "cancelled" && deleted_at = "" && id != {:id} && ' +
        'starts_at < {:end} && ends_at > {:start}',
      'starts_at',
      1,
      0,
      { mechanic: record.getString('mechanic'), id: record.id, start: toPb(start), end: toPb(end) },
    );
    if (busy.length > 0) {
      const other = busy[0];
      throw new ApiError(
        409,
        'Мастер занят с ' +
          hhmm(toDate(other.getString('starts_at'))) +
          ' до ' +
          hhmm(toDate(other.getString('ends_at'))) +
          ' — выберите другое время или мастера',
        {},
      );
    }
  }

  const car = app.findRecordById('cars', record.getString('car'));
  const discount = discountFor(app, car.getString('client'), start);
  record.set('subtotal', subtotal);
  record.set('discount_percent', discount.percent);
  record.set('discount_source', discount.source);
  record.set('total', Math.round((subtotal * (100 - discount.percent)) / 100));
}

// Что мешает физически удалить запись: коллекция → [где ссылаются, фильтр, текст].
const REFERENCES = {
  brands: [['car_models', 'brand = {:id}', 'у марки есть модели']],
  car_models: [['cars', 'model = {:id}', 'есть автомобили этой модели']],
  clients: [['cars', 'client = {:id}', 'у клиента есть автомобили']],
  service_categories: [['services', 'category = {:id}', 'в категории есть услуги']],
  services: [['appointments', 'services ~ {:id}', 'услуга есть в записях на обслуживание']],
  mechanics: [
    ['appointments', 'mechanic = {:id}', 'у мастера есть записи'],
    ['cars', 'mechanics ~ {:id}', 'мастер закреплён за автомобилями'],
  ],
  cars: [['appointments', 'car = {:id}', 'у автомобиля есть записи на обслуживание']],
};

/** 409, если на запись ещё ссылаются другие. */
function checkReferences(app, record) {
  const rules = REFERENCES[record.collection().name] || [];
  for (const rule of rules) {
    const found = app.findRecordsByFilter(rule[0], rule[1], '', 1, 0, { id: record.id });
    if (found.length > 0) {
      throw new ApiError(409, 'Удалить нельзя: ' + rule[2] + '.', {});
    }
  }
}

module.exports = { prepareAppointment, checkReferences, toDate, toPb };
