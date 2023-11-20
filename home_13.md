## Домашнее задание *Бэкапы* ##
### Цель: *Применить логический бэкап. Восстановиться из бэкапа* ###
### *Описание/Пошаговая инструкция выполнения домашнего задания:* ###
- [x] Создаем ВМ/докер c ПГ.
```sh
yc vpc network create --name testnetb; yc vpc subnet create --network-name testnetb --name subnetb --zone 'ru-central1-b' --range '10.0.130.0/24'
yc compute instance create --name tu22p --metadata-from-file user-data=meta.yaml --create-boot-disk name=root-disk2,type=network-ssd,size=10G,auto-delete,image-folder-id=standard-images,image-family=ubuntu-2204-lts --memory 4G --cores 2 --hostname upgtest --metadata serial-port-enable=1 --zone ru-central1-b --core-fraction 50 --preemptible --platform standard-v2; yc compute instance add-one-to-one-nat tu22p --network-interface-index 0 ; yc compute connect-to-serial-port --instance-name tu22p --ssh-key .ssh/yc_serialssh_key --user uuu
```
- [x] Создаем БД, схему и в ней таблицу.
```sh
sudo -u postgres psql <<EOF
create database testdb;
\c testdb
create table testtab (eventtime timestamp , eventname varchar(300) , comm text) ;
EOF
```
```console
CREATE DATABASE
You are now connected to database "testdb" as user "postgres".
CREATE TABLE
```
- [sh] Заполним таблицы автосгенерированными 100 записями.
```sh
sudo -u postgres psql testdb -c " insert into testtab select x, 'test'||random(), (100000.0*random()*log(row_number() over()+1 ) )::varchar(1000) from generate_series(timestamp '2023-01-01',timestamp '2023-01-01'+interval '99' day ,interval '1' day)x "
sudo -u postgres psql testdb -c "select * from testtab limit 1"
```
```console
INSERT 0 100

      eventtime      |        eventname        |       comm
---------------------+-------------------------+-------------------
 2023-01-01 00:00:00 | test0.26542798780896026 | 857.8133041653498
(1 row)
```
- [x] Под линукс пользователем Postgres создадим каталог для бэкапов
```sh
sudo -u postgres mkdir /var/lib/postgresql/pgbackup
```
- [x] Сделаем логический бэкап используя утилиту COPY
```console
sudo -u postgres psql testdb -c "copy testtab to '/var/lib/postgresql/pgbackup/testtab.txt' "
COPY 100
```
- [x] Восстановим в 2 таблицу данные из бэкапа.
```sh
sudo -u postgres psql testdb <<EOF
create table testtab2 (eventtime timestamp , eventname varchar(300) , comm text) ;
copy testtab2 from '/var/lib/postgresql/pgbackup/testtab.txt'
EOF
```
```console
CREATE TABLE
COPY 100
```
- [x] Используя утилиту pg_dump создадим бэкап в кастомном сжатом формате двух таблиц
```sh
sudo -u postgres pg_dump testdb -v -Fc -b -f /var/lib/postgresql/pgbackup/testtab.backup
```
```console
pg_dump: последний системный OID: 16383
pg_dump: чтение расширений
pg_dump: выявление членов расширений
pg_dump: чтение схем
pg_dump: чтение пользовательских таблиц
pg_dump: чтение пользовательских функций
pg_dump: чтение пользовательских типов
pg_dump: чтение процедурных языков
pg_dump: чтение пользовательских агрегатных функций
pg_dump: чтение пользовательских операторов
pg_dump: чтение пользовательских методов доступа
pg_dump: чтение пользовательских классов операторов
pg_dump: чтение пользовательских семейств операторов
pg_dump: чтение пользовательских анализаторов текстового поиска
pg_dump: чтение пользовательских шаблонов текстового поиска
pg_dump: чтение пользовательских словарей текстового поиска
pg_dump: чтение пользовательских конфигураций текстового поиска
pg_dump: чтение пользовательских оболочек сторонних данных
pg_dump: чтение пользовательских сторонних серверов
pg_dump: чтение прав по умолчанию
pg_dump: чтение пользовательских правил сортировки
pg_dump: чтение пользовательских преобразований
pg_dump: чтение приведений типов
pg_dump: чтение преобразований
pg_dump: чтение информации о наследовании таблиц
pg_dump: чтение событийных триггеров
pg_dump: поиск таблиц расширений
pg_dump: поиск связей наследования
pg_dump: чтение информации о столбцах интересующих таблиц
pg_dump: пометка наследованных столбцов в подтаблицах
pg_dump: чтение информации о секционировании
pg_dump: чтение индексов
pg_dump: пометка индексов в секционированных таблицах
pg_dump: чтение расширенной статистики
pg_dump: чтение ограничений
pg_dump: чтение триггеров
pg_dump: чтение правил перезаписи
pg_dump: чтение политик
pg_dump: чтение политик защиты на уровне строк
pg_dump: чтение публикаций
pg_dump: чтение информации о таблицах, включённых в публикации
pg_dump: чтение информации о схемах, включённых в публикации
pg_dump: чтение подписок
pg_dump: чтение больших объектов
pg_dump: чтение информации о зависимостях
pg_dump: сохранение кодировки (UTF8)
pg_dump: сохранение standard_conforming_strings (on)
pg_dump: сохранение search_path =
pg_dump: сохранение определения базы данных
pg_dump: выгрузка содержимого таблицы "public.testtab"
pg_dump: выгрузка содержимого таблицы "public.testtab2"
```
```console
sudo -u postgres pg_restore -l  /var/lib/postgresql/pgbackup/testtab.backup
;
; Archive created at 2023-11-20 18:45:25 MSK
;     dbname: testdb
;     TOC Entries: 8
;     Compression: -1
;     Dump Version: 1.14-0
;     Format: CUSTOM
;     Integer: 4 bytes
;     Offset: 8 bytes
;     Dumped from database version: 15.5 (Ubuntu 15.5-1.pgdg22.04+1)
;     Dumped by pg_dump version: 15.5 (Ubuntu 15.5-1.pgdg22.04+1)
;
;
; Selected TOC Entries:
;
214; 1259 16389 TABLE public testtab postgres
215; 1259 16417 TABLE public testtab2 postgres
3327; 0 16389 TABLE DATA public testtab postgres
3328; 0 16417 TABLE DATA public testtab2 postgres
```

- [x] Используя утилиту pg_restore восстановим в новую БД только вторую таблицу!
```console
sudo -u postgres createdb testdb2;sudo -u postgres pg_restore -d testdb2 -t testtab2 -v  /var/lib/postgresql/pgbackup/testtab.backup
pg_restore: подключение к базе данных для восстановления
pg_restore: создаётся TABLE "public.testtab2"
pg_restore: обрабатываются данные таблицы "public.testtab2"
```
```console
sudo -u postgres psql testdb2 -c "select * from testtab2 limit 1"
      eventtime      |        eventname        |       comm
---------------------+-------------------------+-------------------
 2023-01-01 00:00:00 | test0.26542798780896026 | 857.8133041653498
(1 строка)
```
