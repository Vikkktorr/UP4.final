/// <reference path="../pb_data/types.d.ts" />

// Схема базы автосервиса: коллекции, связи и правила доступа.
// PocketBase применяет миграцию сам при первом запуске `pocketbase serve`.
// Описание для чтения — в pocketbase/схема.md.

// ─── правила доступа ───
// @request.auth — вошедший пользователь из коллекции users (у гостя поля пустые).
const AUTHED = '@request.auth.id != ""';
const ADMIN = '@request.auth.role = "admin"';
const STAFF = '(@request.auth.role = "mechanic" || @request.auth.role = "admin")';
// Мастер меняет только неудалённые записи: удалённую восстанавливает
// и меняет администратор.
const STAFF_EDIT =
  '(@request.auth.role = "admin" || (@request.auth.role = "mechanic" && deleted_at = ""))';

// ─── поля ───
const text = (name, opts = {}) => ({ name, type: 'text', ...opts });
const int = (name, opts = {}) => ({ name, type: 'number', onlyInt: true, ...opts });
const date = (name, opts = {}) => ({ name, type: 'date', ...opts });
const select = (name, values, opts = {}) => ({ name, type: 'select', values, maxSelect: 1, ...opts });
const relation = (name, collection, opts = {}) => ({
  name,
  type: 'relation',
  collectionId: collection.id,
  maxSelect: 1,
  cascadeDelete: false,
  ...opts,
});
// Логическое удаление: пустая дата — запись действует.
const deletedAt = () => date('deleted_at');
const timestamps = () => [
  { name: 'created', type: 'autodate', onCreate: true, onUpdate: false },
  { name: 'updated', type: 'autodate', onCreate: true, onUpdate: true },
];

/** Справочник: читают все вошедшие, ведут мастер и администратор. */
function referenceRules() {
  return {
    listRule: AUTHED,
    viewRule: AUTHED,
    createRule: STAFF,
    updateRule: STAFF_EDIT,
    deleteRule: ADMIN,
  };
}

migrate(
  (app) => {
    const save = (data) => {
      const collection = new Collection(data);
      app.save(collection);
      return collection;
    };

    // 1. Марки
    const brands = save({
      type: 'base',
      name: 'brands',
      ...referenceRules(),
      fields: [
        text('name', { required: true, max: 40 }),
        text('country', { required: true, max: 40 }),
        deletedAt(),
        ...timestamps(),
      ],
      indexes: ['CREATE UNIQUE INDEX idx_brands_name ON brands (name)'],
    });

    // 2. Модели — марка 1:N модели
    const carModels = save({
      type: 'base',
      name: 'car_models',
      ...referenceRules(),
      fields: [
        relation('brand', brands, { required: true }),
        text('name', { required: true, max: 40 }),
        deletedAt(),
        ...timestamps(),
      ],
      indexes: ['CREATE UNIQUE INDEX idx_car_models_brand_name ON car_models (brand, name)'],
    });

    // 3. Клиенты. Клиент видит только свою запись.
    const clients = save({
      type: 'base',
      name: 'clients',
      listRule: `${STAFF} || id = @request.auth.client`,
      viewRule: `${STAFF} || id = @request.auth.client`,
      createRule: STAFF,
      updateRule: STAFF_EDIT,
      deleteRule: ADMIN,
      fields: [
        text('last_name', { required: true, max: 40 }),
        text('first_name', { required: true, max: 40 }),
        text('middle_name', { max: 40 }),
        // Телефон обязателен в форме; при регистрации клиента его ещё нет.
        text('phone', { max: 20 }),
        { name: 'email', type: 'email' },
        int('discount', { min: 0, max: 30 }),
        date('registered_at'),
        deletedAt(),
        ...timestamps(),
      ],
    });

    // 4. Клубные карты — клиент 1:1 карта (уникальный индекс по client).
    // Удаляется вместе с клиентом.
    save({
      type: 'base',
      name: 'club_cards',
      listRule: `${STAFF} || client = @request.auth.client`,
      viewRule: `${STAFF} || client = @request.auth.client`,
      createRule: STAFF,
      updateRule: STAFF,
      deleteRule: STAFF,
      fields: [
        relation('client', clients, { required: true, cascadeDelete: true }),
        text('number', { required: true, pattern: '^AS-\\d{6}$' }),
        select('level', ['standard', 'silver', 'gold'], { required: true }),
        date('issued_at', { required: true }),
        date('expires_at', { required: true }),
        int('bonus_points', { min: 0, max: 1000000 }),
        ...timestamps(),
      ],
      indexes: [
        'CREATE UNIQUE INDEX idx_club_cards_client ON club_cards (client)',
        'CREATE UNIQUE INDEX idx_club_cards_number ON club_cards (number)',
      ],
    });

    // 5. Мастера. Список нужен и клиенту — чтобы записаться.
    const mechanics = save({
      type: 'base',
      name: 'mechanics',
      ...referenceRules(),
      fields: [
        text('last_name', { required: true, max: 40 }),
        text('first_name', { required: true, max: 40 }),
        text('middle_name', { max: 40 }),
        text('phone', { required: true, max: 20 }),
        int('grade', { required: true, min: 1, max: 6 }),
        int('experience', { min: 0, max: 60 }),
        date('hired_at'),
        deletedAt(),
        ...timestamps(),
      ],
    });

    // 6. Автомобили — модель 1:N, клиент 1:N, мастера M:N (до трёх).
    const cars = save({
      type: 'base',
      name: 'cars',
      listRule: `${STAFF} || client = @request.auth.client`,
      viewRule: `${STAFF} || client = @request.auth.client`,
      createRule: STAFF,
      updateRule: STAFF_EDIT,
      deleteRule: ADMIN,
      fields: [
        text('plate', { required: true, max: 9 }),
        text('vin', { required: true, min: 17, max: 17 }),
        relation('model', carModels, { required: true }),
        int('year', { required: true, min: 1950, max: 2100 }),
        int('mileage', { min: 0, max: 2000000 }),
        select('fuel', ['petrol', 'diesel', 'gas', 'hybrid', 'electric'], { required: true }),
        relation('client', clients, { required: true }),
        relation('mechanics', mechanics, { minSelect: 1, maxSelect: 3, required: true }),
        deletedAt(),
        ...timestamps(),
      ],
      indexes: [
        'CREATE UNIQUE INDEX idx_cars_plate ON cars (plate)',
        'CREATE UNIQUE INDEX idx_cars_vin ON cars (vin)',
      ],
    });

    // 7. Категории услуг — категория 1:N услуги
    const categories = save({
      type: 'base',
      name: 'service_categories',
      ...referenceRules(),
      fields: [text('name', { required: true, max: 40 }), deletedAt(), ...timestamps()],
      indexes: ['CREATE UNIQUE INDEX idx_service_categories_name ON service_categories (name)'],
    });

    // 8. Услуги
    const services = save({
      type: 'base',
      name: 'services',
      ...referenceRules(),
      fields: [
        text('name', { required: true, max: 60 }),
        relation('category', categories, { required: true }),
        int('price', { required: true, min: 1, max: 1000000 }),
        // Норма времени в минутах
        int('duration', { required: true, min: 5, max: 600 }),
        deletedAt(),
        ...timestamps(),
      ],
      indexes: ['CREATE UNIQUE INDEX idx_services_name ON services (name)'],
    });

    // 9. Записи на обслуживание — автомобиль 1:N, мастер 1:N, услуги M:N.
    // Окончание и стоимость считает сервер (pb_hooks), присланные клиентом
    // значения этих полей не используются.
    const clientOwnCar = '@request.auth.role = "client" && car.client = @request.auth.client';
    save({
      type: 'base',
      name: 'appointments',
      listRule: `${STAFF} || (${clientOwnCar})`,
      viewRule: `${STAFF} || (${clientOwnCar})`,
      // Клиент записывает только свой автомобиль и только со статусом «запланирована».
      createRule:
        `${STAFF} || (@request.auth.role = "client" && ` +
        '@request.body.car.client = @request.auth.client && @request.body.status = "planned")',
      // Клиент может только отменить свою запланированную запись.
      updateRule:
        `${STAFF_EDIT} || (${clientOwnCar} && status = "planned" && ` +
        '@request.body.status = "cancelled" && @request.body.car:isset = false && ' +
        '@request.body.mechanic:isset = false && @request.body.services:isset = false && ' +
        '@request.body.starts_at:isset = false && @request.body.deleted_at:isset = false)',
      deleteRule: ADMIN,
      fields: [
        relation('car', cars, { required: true }),
        relation('mechanic', mechanics, { required: true }),
        relation('services', services, { minSelect: 1, maxSelect: 20, required: true }),
        date('starts_at', { required: true }),
        date('ends_at'),
        select('status', ['planned', 'in_progress', 'done', 'cancelled'], { required: true }),
        int('subtotal', { min: 0 }),
        int('discount_percent', { min: 0, max: 100 }),
        select('discount_source', ['none', 'card', 'personal']),
        int('total', { min: 0 }),
        text('comment', { max: 300 }),
        deletedAt(),
        ...timestamps(),
      ],
      indexes: ['CREATE INDEX idx_appointments_mechanic_time ON appointments (mechanic, starts_at)'],
    });

    // Занятость мастеров без подробностей: клиенту при записи нужно видеть
    // свободное время, но не чужие автомобили и суммы.
    save({
      type: 'view',
      name: 'mechanic_busy',
      listRule: AUTHED,
      viewRule: AUTHED,
      viewQuery:
        "SELECT id, mechanic, starts_at, ends_at FROM appointments " +
        "WHERE status != 'cancelled' AND deleted_at = ''",
    });

    // 10. Пользователи — встроенная коллекция users, дополняем.
    const users = app.findCollectionByNameOrId('users');
    users.fields.add(new Field(text('username', { required: true, min: 3, max: 20, pattern: '^[A-Za-z0-9_]+$' })));
    users.fields.add(new Field(text('last_name', { max: 40 })));
    users.fields.add(new Field(text('first_name', { max: 40 })));
    users.fields.add(new Field(select('role', ['client', 'mechanic', 'admin'], { required: true })));
    // Связь пользователя с клиентом или мастером — 1:1
    users.fields.add(new Field(relation('client', clients)));
    users.fields.add(new Field(relation('mechanic', mechanics)));
    users.fields.getByName('email').required = false;
    users.addIndex('idx_users_username', true, 'username', '');
    users.passwordAuth.identityFields = ['username', 'email'];
    // Токен живёт 15 минут, приложение обновляет его заранее.
    users.authToken.duration = 15 * 60;
    users.listRule = `id = @request.auth.id || ${ADMIN}`;
    users.viewRule = `id = @request.auth.id || ${ADMIN}`;
    // Регистрация открыта, но только с ролью клиента и без чужих связей.
    users.createRule =
      `${ADMIN} || (@request.body.role = "client" && ` +
      '@request.body.client:isset = false && @request.body.mechanic:isset = false)';
    users.updateRule =
      `${ADMIN} || (id = @request.auth.id && @request.body.role:isset = false && ` +
      '@request.body.client:isset = false && @request.body.mechanic:isset = false)';
    users.deleteRule = ADMIN;
    app.save(users);

    // Множественное удаление одним запросом /api/batch
    const settings = app.settings();
    settings.batch.enabled = true;
    settings.batch.maxRequests = 100;
    settings.meta.appName = 'Автосервис';
    app.save(settings);
  },
  (app) => {
    for (const name of [
      'mechanic_busy',
      'appointments',
      'services',
      'service_categories',
      'cars',
      'mechanics',
      'club_cards',
      'clients',
      'car_models',
      'brands',
    ]) {
      try {
        app.delete(app.findCollectionByNameOrId(name));
      } catch (_) {}
    }
  },
);
