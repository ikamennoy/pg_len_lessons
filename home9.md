# Домашнее задание - *Работа с журналами* #
## Цель: ##
- уметь работать с журналами и контрольными точками
- уметь настраивать параметры журналов

---------------------------------------------------------------------------

## Описание/Пошаговая инструкция выполнения домашнего задания: ##

- [x] Настройте выполнение контрольной точки раз в 30 секунд.
```sh
psql -c "alter system set checkpoint_timeout = 30"
#psql -c "alter system set wal_keep_size=0"
psql -c "alter system set checkpoint_warning = 30"
psql -c "ALTER SYSTEM SET log_checkpoints = on"
psql -c "SELECT pg_reload_conf()"
psql -c "show checkpoint_timeout; show checkpoint_warning ; show log_checkpoints "
psql -c "drop database testdb"
psql -c "create database testdb"
pgbench -i testdb
```
```console
postgres@upgtest:~$ psql -c "SELECT * FROM pg_stat_bgwriter "
 checkpoints_timed | checkpoints_req | checkpoint_write_time | checkpoint_sync_time | buffers_checkpoint | buffers_clean | maxwritten_clean | buffers_backend | buffers_backend_fsync | buffers_alloc |          stats_reset
-------------------+-----------------+-----------------------+----------------------+--------------------+---------------+------------------+-----------------+-----------------------+---------------+-------------------------------
               481 |               8 |               5827687 |                 4544 |             215572 |             0 |                0 |           21629 |                     0 |         35928 | 2023-10-31 05:32:48.720814+03
(1 строка)

postgres@upgtest:~$ psql -c "SELECT pg_stat_reset_shared('bgwriter');"
 pg_stat_reset_shared
----------------------

(1 строка)

postgres@upgtest:~$ psql -c "SELECT * FROM pg_stat_bgwriter "
 checkpoints_timed | checkpoints_req | checkpoint_write_time | checkpoint_sync_time | buffers_checkpoint | buffers_clean | maxwritten_clean | buffers_backend | buffers_backend_fsync | buffers_alloc |          stats_reset
-------------------+-----------------+-----------------------+----------------------+--------------------+---------------+------------------+-----------------+-----------------------+---------------+-------------------------------
                 0 |               0 |                     0 |                    0 |                  0 |             0 |                0 |               0 |                     0 |             8 | 2023-10-31 20:07:54.464494+03
(1 строка)
```

---------------------------------------------------------------------------

- [x] 10 минут c помощью утилиты pgbench подавайте нагрузку.

```sh
psql -c "SELECT pg_current_wal_lsn(),now() ;SELECT pg_stat_reset_shared('bgwriter') /* https://postgrespro.ru/docs/postgresql/15/functions-admin */ " ; time pgbench -c20 -T 600 -U postgres testdb;psql -c "SELECT pg_current_wal_lsn(),now() ; select name,pg_size_pretty(size) as size, modification, modification - lag(modification) over(partition by null order by modification ) as mod from pg_ls_waldir ()z; SELECT * FROM pg_stat_bgwriter "
```

```console
psql -c "SELECT pg_current_wal_lsn(),now() ;SELECT pg_stat_reset_shared('bgwriter') " ; time pgbench -c20 -T 600 -U postgres testdb;psql -c "SELECT pg_current_wal_lsn(),now() ; select name,pg_size_pretty(size) as size
, modification, modification - lag(modification) over(partition by null order by modification ) as mod from pg_ls_waldir ()z; SELECT * FROM pg_stat_bgwriter "
 pg_current_wal_lsn |              now
--------------------+-------------------------------
 1/19EF40           | 2023-10-31 20:57:44.909309+03
(1 строка)

 pg_stat_reset_shared
----------------------

(1 строка)

pgbench (15.4 (Ubuntu 15.4-2.pgdg22.04+1))
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 20
number of threads: 1
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 184974
number of failed transactions: 0 (0.000%)
latency average = 64.874 ms
initial connection time = 108.510 ms
tps = 308.289991 (without initial connection time)

real    10m0,169s
user    0m12,347s
sys     0m25,776s
 pg_current_wal_lsn |              now
--------------------+-------------------------------
 1/17A6C650         | 2023-10-31 21:07:45.134279+03
(1 строка)

           name           | size  |      modification      |   mod
--------------------------+-------+------------------------+----------
 000000010000000100000018 | 16 MB | 2023-10-31 21:06:10+03 |
 000000010000000100000019 | 16 MB | 2023-10-31 21:06:34+03 | 00:00:24
 000000010000000100000015 | 16 MB | 2023-10-31 21:07:03+03 | 00:00:29
 000000010000000100000016 | 16 MB | 2023-10-31 21:07:27+03 | 00:00:24
 000000010000000100000017 | 16 MB | 2023-10-31 21:07:45+03 | 00:00:18
(5 строк)

 checkpoints_timed | checkpoints_req | checkpoint_write_time | checkpoint_sync_time | buffers_checkpoint | buffers_clean | maxwritten_clean | buffers_backend | buffers_backend_fsync | buffers_alloc |          stats_reset
-------------------+-----------------+-----------------------+----------------------+--------------------+---------------+------------------+-----------------+-----------------------+---------------+-------------------------------
                20 |               0 |                510859 |                  493 |              35030 |             0 |                0 |            1204 |                     0 |          1197 | 2023-10-31 20:57:44.909977+03
(1 строка)
```


---------------------------------------------------------------------------

- [x] Измерьте, какой объем журнальных файлов был сгенерирован за это время. Оцените, какой объем приходится в среднем на одну контрольную точку.
```sql
select pg_catalog.pg_size_pretty('1/17A6C650'::pg_lsn  - '1/19EF40'::pg_lsn); --  377 MB  ( было 115 MB если checkpoint_timeout=5m - чаще сохраняем - больше промежуточных данных)
```

|Т.к. [checkpoints_timed](https://habr.com/ru/companies/postgrespro/articles/460423/) = 20 (см выше) , то `select pg_catalog.pg_size_pretty(('1/17A6C650'::pg_lsn  - '1/19EF40'::pg_lsn)/20);` 19 MB - средний объем на 1 контрольную точку|
|-|
|Для обеспечения целостности страницы данных, при первом изменении страницы данных после контрольной точки эта страница записывается в журнал целиком.  чем меньше интервал между контрольными точками, тем больше объём записи в журнал [WAL](https://postgrespro.ru/docs/postgrespro/15/wal-configuration).|


---------------------------------------------------------------------------

- [x] Проверьте данные статистики: все ли контрольные точки выполнялись точно по расписанию. Почему так произошло?
checkpoints_timed 20, checkpoints_req =0 (см выше) - т.е. размер WAL не превысил max_wal_size

```
WAL files are stored in the directory pg_wal under the data directory, as a set of segment files, normally each 16 MB in size (but the size can be changed by altering the --wal-segsize initdb option). Each segment is divided into pages, normally 8 kB each (this size can be changed via the --with-wal-blocksize configure option). The WAL record headers are described in access/xlogrecord.h; the record content is dependent on the type of event that is being logged. Segment files are given ever-increasing numbers as names, starting at 000000010000000000000001. The numbers do not wrap, but it will take a very, very long time to exhaust the available stock of numbers.
```


- [x] Сравните tps в синхронном/асинхронном режиме утилитой pgbench. Объясните полученный результат.
```sh
psql -c "alter system set synchronous_commit = off;alter system set wal_writer_delay = 200;show synchronous_commit;show wal_writer_delay;" ; psql -c "SELECT pg_current_wal_lsn(),now() ";time pgbench -c20 -P 60 -T 600 -U postgres testdb;psql -c "SELECT pg_current_wal_lsn(),now() ; select name,pg_size_pretty(size) as size, modification, modification - lag(modification) over(partition by null order by modification ) as mod from pg_ls_waldir ()z; "
```

```initial connection time = 61.931 ms
tps = 353.582338 (without initial connection time)
```


#### - разницы скорее мало т.к. checkpoint_timeout = 30 , проверим ####


```cmd
psql -c "alter system set synchronous_commit = off" ; psql -c "alter system set wal_writer_delay = 200" ; psql -c "alter system set checkpoint_timeout = 300" ; psql -c "SELECT pg_reload_conf()" ; psql -c  "show synchronous_commit;show wal_writer_delay; show checkpoint_timeout;" ; psql -c "SELECT pg_current_wal_lsn(),now() ";time pgbench -c20 -T 600 -U postgres testdb;psql -c "SELECT pg_current_wal_lsn(),now() ; select name,pg_size_pretty(size) as size, modification, modification - lag(modification) over(partition by null order by modification ) as mod from pg_ls_waldir ()z; "
```

```console
ALTER SYSTEM
ALTER SYSTEM
 pg_reload_conf
----------------
 t
(1 строка)

 synchronous_commit
--------------------
 off
(1 строка)

 wal_writer_delay
------------------
 200ms
(1 строка)

 checkpoint_timeout
--------------------
 5min
(1 строка)

 pg_current_wal_lsn |             now
--------------------+------------------------------
 1/3A96D8C0         | 2023-10-31 22:50:13.96968+03
(1 строка)

pgbench (15.4 (Ubuntu 15.4-2.pgdg22.04+1))
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 20
number of threads: 1
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 1242932
number of failed transactions: 0 (0.000%)
latency average = 9.654 ms
initial connection time = 58.546 ms
tps = 2071.574543 (without initial connection time)

real    10m0,102s
user    1m1,431s
sys     2m22,965s
 pg_current_wal_lsn |              now
--------------------+-------------------------------
 1/60EE6000         | 2023-10-31 23:00:14.117524+03
(1 строка)

           name           | size  |      modification      |   mod
--------------------------+-------+------------------------+----------
 00000001000000010000003D | 16 MB | 2023-10-31 22:51:00+03 |
 00000001000000010000003E | 16 MB | 2023-10-31 22:51:11+03 | 00:00:11
 00000001000000010000003F | 16 MB | 2023-10-31 22:51:27+03 | 00:00:16
 000000010000000100000040 | 16 MB | 2023-10-31 22:51:43+03 | 00:00:16
 000000010000000100000041 | 16 MB | 2023-10-31 22:51:59+03 | 00:00:16
 000000010000000100000042 | 16 MB | 2023-10-31 22:52:15+03 | 00:00:16
 000000010000000100000043 | 16 MB | 2023-10-31 22:52:31+03 | 00:00:16
 000000010000000100000044 | 16 MB | 2023-10-31 22:52:46+03 | 00:00:15
 000000010000000100000045 | 16 MB | 2023-10-31 22:53:03+03 | 00:00:17
 000000010000000100000046 | 16 MB | 2023-10-31 22:53:18+03 | 00:00:15
 000000010000000100000047 | 16 MB | 2023-10-31 22:53:33+03 | 00:00:15
 000000010000000100000048 | 16 MB | 2023-10-31 22:53:49+03 | 00:00:16
 000000010000000100000049 | 16 MB | 2023-10-31 22:54:05+03 | 00:00:16
 00000001000000010000004A | 16 MB | 2023-10-31 22:54:20+03 | 00:00:15
 00000001000000010000004B | 16 MB | 2023-10-31 22:54:35+03 | 00:00:15
 00000001000000010000004C | 16 MB | 2023-10-31 22:54:50+03 | 00:00:15
 00000001000000010000004D | 16 MB | 2023-10-31 22:55:07+03 | 00:00:17
 00000001000000010000004E | 16 MB | 2023-10-31 22:55:23+03 | 00:00:16
 00000001000000010000004F | 16 MB | 2023-10-31 22:55:38+03 | 00:00:15
 000000010000000100000050 | 16 MB | 2023-10-31 22:55:53+03 | 00:00:15
 000000010000000100000051 | 16 MB | 2023-10-31 22:56:01+03 | 00:00:08
```

####     ого tps вырос - когда checkpoint_timeout вернул на 300 с 220+ до 2000+ - вырос почти в 10 раз tps    #### 


---------------------------------------------------------------------------

- [x] Создайте новый кластер с включенной контрольной суммой страниц.
```sh
mkdir /etc/postgresql-common/createcluster.d/
echo "initdb_options = '--data-checksums'" | sudo tee /etc/postgresql-common/createcluster.d/initdb_options.conf
pg_createcluster 15 main
su postgres
pg_ctlcluster 15 main start
psql -c "show ignore_checksum_failure;show data_checksums"
```


```console
 ignore_checksum_failure
-------------------------
 off
(1 row)
```

  -  [x] Создайте таблицу.
```sh
psql -c "create table t2(nn int4)"
```

  -  [x] Вставьте несколько значений.
```console
psql -c "insert into t2 select x nn from generate_series(1,1000)x;select pg_relation_filepath('t2');"
INSERT 0 1000
 pg_relation_filepath
----------------------
 base/5/16384
(1 row)
```

  -  [x] Выключите кластер.
```
pg_ctlcluster 15 main stop

ls -hs /var/lib/postgresql/15/main/base/5/16384*
40K /var/lib/postgresql/15/main/base/5/16384
24K /var/lib/postgresql/15/main/base/5/16384_fsm
```
  -  [x] Измените пару байт в таблице.
`hexedit /var/lib/postgresql/15/main/base/5/16384`
  -  [x] Включите кластер и сделайте выборку из таблицы.
При чтении проверяется контрольная сумма.
```console
$ pg_ctlcluster 15 main start
$ psql -c "select nn,ctid from t2 limit 20"
ПРЕДУПРЕЖДЕНИЕ:  ошибка проверки страницы: получена контрольная сумма 61487, а ожидалась - 51864
ОШИБКА:  неверная страница в блоке 0 отношения base/5/16384
```
  -  [x] Что и почему произошло? как проигнорировать ошибку и продолжить работу?
Так как CRC как раз для этого - что если изменилась контрольная сумма у файла - то значит файл поврежден.
Чтобы продолжить работу на уровне сессии
```sql
set ignore_checksum_failure=on;
select nn,ctid from t2 limit 20; -- работает
```

  [ignore_checksum_failure / zero_damaged_pages / ignore_invalid_pages](https://www.postgresql.org/docs/16/runtime-config-developer.html#GUC-IGNORE-CHECKSUM-FAILURE)

В идеале если ошибок много ... лучше восстановиться из бэкапа и не продолжать работу , т.к. битые данные могут быть значительно повреждены и непросто оценить насколько.
можно изменить на уровне системы:
```sh
psql -c "alter system set  ignore_checksum_failure=on"
```

