# 3 Установка и настройка PostgteSQL в контейнере Docker #
> ## Цель: ##
> * установить PostgreSQL в Docker контейнере
> * настроить контейнер для внешнего подключения
> ## Описание/Пошаговая инструкция выполнения домашнего задания: ##
> * создать ВМ с Ubuntu 20.04/22.04 или развернуть докер любым удобным способом
> * поставить на нем Docker Engine
> * сделать каталог /var/lib/postgres
```sh
apt install docker.io docker-compose -y > /dev/null
docker network create testnet
```

> * развернуть контейнер с PostgreSQL 15 смонтировав в него /var/lib/postgresql
```sh

cat > compose.yaml <<EOF
version: "3.8"

networks:
  testnet:
    external: true

services:
 pgdb:
  image: postgres:15
  environment:
    POSTGRES_PASSWORD: test1234
  networks:
    - testnet
  ports:
    - "5433:5432"
  volumes:
    - /var/lib/postgresql/ddata:/var/lib/postgresql/data
EOF

docker-compose up -d> /dev/null
cat /var/lib/postgresql/ddata/PG_VERSION
docker exec -it `docker ps -q -f name=pgdb`  pg_createcluster 15 main
docker exec -it `docker ps -q -f name=pgdb`  pg_ctlcluster 15 main start
docker exec -it `docker ps -q -f name=pgdb`  psql -U postgres -W -h 127.0.0.1

```

```sql
create database test;
create role test password 'test';
\c test;
create table testtab as select split_part(x,',',1) as x, split_part(x,',',2) as y from regexp_split_to_table('aaa,bbb;ccc,ddd', ';') x;
```
```
test=# \dt
          List of relations
 Schema |  Name   | Type  |  Owner
--------+---------+-------+----------
 public | testtab | table | postgres
(1 row)

test=# select * from testtab
test-# ;
  x  |  y
-----+-----
 aaa | bbb
 ccc | ddd
(2 rows)
```
> * развернуть контейнер с клиентом postgres
```sh
docker run --rm --network testnet -it -e PGPASSWORD=test1234 postgres:15 /usr/bin/psql -h pgdb -U postgres test
```
> * подключится из контейнера с клиентом к контейнеру с сервером и сделать таблицу с парой строк
```sh
echo "create table testtab2 as select split_part(x,',',1) as x, split_part(x,',',2) as y from regexp_split_to_table('aaa,bbb;ccc,ddd', ';') x;" > testtab2.sql
docker run --rm --network testnet -it -e PGPASSWORD=test1234 -v ./testtab2.sql:/testtab2.sql postgres:15 /usr/bin/psql -h pgdb -U postgres test -f /testtab2.sql
```
> * подключится к контейнеру с сервером с ноутбука/компьютера извне инстансов GCP/ЯО/места установки докера
```sh
PGPASSWORD="test1234" psql -h 172.22.254.224 -p 5433 -U postgres test -c "select * from testtab2"
  x  |  y
-----+-----
 aaa | bbb
 ccc | ddd
(2 rows)
```
> * удалить контейнер с сервером
```
for i in stop rm ; do docker $i `docker ps -a -q -f name=pgdb` ; done
docker ps -a| wc -l
0
```
удалился

> * создать его заново
```
docker-compose up -d
Creating root_pgdb_1 ... done
```
>   * подключится снова из контейнера с клиентом к контейнеру с сервером
>   * проверить, что данные остались на месте
```
PGPASSWORD="test1234" psql -h 172.22.254.224 -p 5433 -U postgres test -c "select * from testtab2"
  x  |  y
-----+-----
 aaa | bbb
 ccc | ddd
(2 rows)
```

> * оставляйте в ЛК ДЗ комментарии что и как вы делали и как боролись с проблемами
* поставил докер из репа - т.к. достаточно свежий для меня там.
* посмотрел
* * https://postgrespro.ru/docs/postgresql/9.6/libpq-envars ,
  * https://docs.docker.com/engine/reference/run/#cmd-default-command-or-options ,
  * https://docs.docker.com/compose/compose-file/06-networks/#internal,
  * https://docs.docker.com/compose/networking/
  * https://kubernetes.io/docs/concepts/containers/
  * https://unofficial-kubernetes.readthedocs.io/en/latest/concepts/containers/images/
  * Правда при переходе на кубер от сборки докер отказываются в пользу podman https://habr.com/ru/articles/659049/
  * https://wiki.archlinux.org/title/Systemd-nspawn
  * https://habr.com/ru/companies/yandex_praktikum/articles/570024/ eshulyndina 29 июл 2021 в 15:26 Микросервисы vs. Монолит
  * https://vc.ru/services/696182-kak-stroit-biznes-prilozheniya-mikroservisy-monolit-i-kubernetes-legkoe-pogruzhenie-s-nulya

* создал compose.yaml - с указанием маппинга портов, сети, образов, нужного образа postgresql с версией 15
* запустил docker-compose
* запускал клиент в отдельном контейнере по имени хоста, в том же контейнере, с локального хоста
* пересоздал контейнера
* повторил запросы к базе
