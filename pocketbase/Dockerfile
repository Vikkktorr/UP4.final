# PocketBase «Автосервиса» для размещения в интернете (Render).
# В образе: сервер, миграция схемы, хуки и демонстрационные данные.
# Данные заливаются при каждом запуске контейнера — даты записей на
# обслуживание отсчитываются от дня запуска.
FROM node:22-alpine

ARG PB_VERSION=0.40.4
RUN wget -q -O /tmp/pb.zip \
      https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip \
 && unzip -q /tmp/pb.zip pocketbase -d /pb \
 && rm /tmp/pb.zip

WORKDIR /pb
COPY pb_migrations ./pb_migrations
COPY pb_hooks ./pb_hooks
COPY seed.mjs seed-data.json start.sh ./

CMD ["sh", "start.sh"]
