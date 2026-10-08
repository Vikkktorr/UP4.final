/// <reference path="../pb_data/types.d.ts" />

// Серверные правила автосервиса. Функции — в autoservice_lib.js.

// Запись на обслуживание: окончание, рабочие часы, занятость мастера (409),
// стоимость со скидкой. Считает сервер, а не приложение.
onRecordCreateRequest((e) => {
  require(`${__hooks}/autoservice_lib.js`).prepareAppointment(e.app, e.record);
  e.next();
}, 'appointments');

onRecordUpdateRequest((e) => {
  require(`${__hooks}/autoservice_lib.js`).prepareAppointment(e.app, e.record);
  e.next();
}, 'appointments');

// Физическое удаление записи, на которую ссылаются другие, — 409.
onRecordDeleteRequest(
  (e) => {
    require(`${__hooks}/autoservice_lib.js`).checkReferences(e.app, e.record);
    e.next();
  },
  'brands',
  'car_models',
  'clients',
  'service_categories',
  'services',
  'mechanics',
  'cars',
);

// Регистрация: у нового клиента сразу появляется карточка клиента,
// к которой мастер потом добавит автомобили.
onRecordCreateRequest((e) => {
  e.next();
  const user = e.record;
  if (user.getString('role') !== 'client' || user.getString('client')) return;
  const client = new Record(e.app.findCollectionByNameOrId('clients'));
  client.set('last_name', user.getString('last_name'));
  client.set('first_name', user.getString('first_name'));
  client.set('email', user.getString('email'));
  client.set('registered_at', new Date().toISOString().replace('T', ' '));
  e.app.save(client);
  user.set('client', client.id);
  e.app.save(user);
}, 'users');

// Администратор не меняет собственную роль и не удаляет сам себя.
onRecordUpdateRequest((e) => {
  const auth = e.auth;
  if (auth && auth.id === e.record.id && e.record.getString('role') !== e.record.original().getString('role')) {
    throw new ApiError(409, 'Нельзя изменить собственную роль.', {});
  }
  e.next();
}, 'users');

onRecordDeleteRequest((e) => {
  if (e.auth && e.auth.id === e.record.id) {
    throw new ApiError(409, 'Нельзя удалить собственную учётную запись.', {});
  }
  e.next();
}, 'users');
