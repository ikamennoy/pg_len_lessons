# _Домашнее задание_ Настройка autovacuum с учетом особенностей производительности #

## Цель: ##
- запустить нагрузочный тест pgbench
- настроить параметры autovacuum
- проверить работу autovacuum

## Описание/Пошаговая инструкция выполнения домашнего задания: ##

   [meta.yaml](home7/meta.yaml)
 
 
 - [x] Создать инстанс ВМ с 2 ядрами и 4 Гб ОЗУ и SSD 10GB
 ```sh
yc vpc network create --name testnetb
yc vpc subnet create --network-name testnetb --name subnetb --zone 'ru-central1-b' --range '10.0.130.0/24'
yc compute instance create --name tu22p --metadata-from-file user-data=meta.yaml --create-boot-disk name=root-disk2,type=network-ssd,size=10G,auto-delete,image-folder-id=standard-images,image-family=ubuntu-2204-lts --memory 4G --cores 2 --hostname upgtest --metadata serial-port-enable=1 --zone ru-central1-b --core-fraction 50 --preemptible --platform standard-v2
yc compute instance add-one-to-one-nat tu22p --network-interface-index 0
yc compute connect-to-serial-port --instance-name tu22p --ssh-key .ssh/yc_serialssh_key --user uuu

```
Console: [out1.md](home7/out1.md)
 - [x] Установить на него PostgreSQL 15 с дефолтными настройками
 via: [once.sh](home7/once.sh)
 - [x] Создать БД для тестов: выполнить `pgbench -i testdb`
```console
pgbench -i postgres
dropping old tables...
ЗАМЕЧАНИЕ:  таблица "pgbench_accounts" не существует, пропускается
ЗАМЕЧАНИЕ:  таблица "pgbench_branches" не существует, пропускается
ЗАМЕЧАНИЕ:  таблица "pgbench_history" не существует, пропускается
ЗАМЕЧАНИЕ:  таблица "pgbench_tellers" не существует, пропускается
creating tables...
generating data (client-side)...
100000 of 100000 tuples (100%) done (elapsed 0.11 s, remaining 0.00 s)
vacuuming...
creating primary keys...
done in 0.82 s (drop tables 0.00 s, create tables 0.03 s, client-side generate 0.51 s, vacuum 0.07 s, primary keys 0.21 s).
```

 - [x] Запустить `pgbench -c8 -P 6 -T 60 -U postgres testdb`
```console
testdb=# \dt+
                                         Список отношений
 Схема  |       Имя        |   Тип   | Владелец |  Хранение  | Метод доступа | Размер  | Описание
--------+------------------+---------+----------+------------+---------------+---------+----------
 public | pgbench_accounts | таблица | postgres | постоянное | heap          | 13 MB   |
 public | pgbench_branches | таблица | postgres | постоянное | heap          | 40 kB   |
 public | pgbench_history  | таблица | postgres | постоянное | heap          | 0 bytes |
 public | pgbench_tellers  | таблица | postgres | постоянное | heap          | 40 kB   |
(4 строки)
```

```console
time pgbench -c8 -P 6 -T 60 -U postgres testdb
pgbench (15.4 (Ubuntu 15.4-2.pgdg22.04+1))
starting vacuum...end.
progress: 6.0 s, 335.5 tps, lat 23.147 ms stddev 15.975, 0 failed
progress: 12.0 s, 214.7 tps, lat 38.071 ms stddev 59.752, 0 failed
progress: 18.0 s, 344.2 tps, lat 23.146 ms stddev 14.941, 0 failed
progress: 24.0 s, 341.0 tps, lat 23.475 ms stddev 19.235, 0 failed
progress: 30.0 s, 266.3 tps, lat 30.082 ms stddev 23.301, 0 failed
progress: 36.0 s, 175.0 tps, lat 45.669 ms stddev 33.256, 0 failed
progress: 42.0 s, 115.2 tps, lat 68.464 ms stddev 95.230, 0 failed
progress: 48.0 s, 276.0 tps, lat 29.524 ms stddev 40.016, 0 failed
progress: 54.0 s, 267.2 tps, lat 29.903 ms stddev 19.216, 0 failed
progress: 60.0 s, 283.7 tps, lat 28.197 ms stddev 20.865, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 1
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 15720
number of failed transactions: 0 (0.000%)
latency average = 30.530 ms
latency stddev = 35.898 ms
initial connection time = 25.979 ms
tps = 261.961946 (without initial connection time)

real    1m0,079s
user    0m0,973s
sys     0m2,282s
```
 
 - [x] Применить параметры настройки PostgreSQL из прикрепленного к материалам занятия файла
```console
pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
15  main    5432 online postgres /var/lib/postgresql/15/main /var/log/postgresql/postgresql-15-main.log
```

```sh
cp /etc/postgresql/15/main/postgresql.conf{,.1}
cd /tmp/
wget https://raw.githubusercontent.com/ikamennoy/pg_len_lessons/main/home7/pg_attach.conf
sed  's/#.*//g' /etc/postgresql/15/main/postgresql.conf.1 | grep '=' > /etc/postgresql/15/main/postgresql.conf
words_del="`cat pg_attach.conf |grep = |cut -d = -f 1`"
for i in $words_del ; do sed -ie "/^$i = /d" /etc/postgresql/15/main/postgresql.conf  ; done
cat pg_attach.conf >> /etc/postgresql/15/main/postgresql.conf
pg_ctlcluster 15 main start
```
[postgresql_new.conf](home7/postgresql_new.conf)

 - [x] Протестировать заново
```console
time pgbench -c8 -P 6 -T 60 -U postgres testdb
pgbench (15.4 (Ubuntu 15.4-2.pgdg22.04+1))
starting vacuum...end.
progress: 6.0 s, 321.7 tps, lat 24.731 ms stddev 17.551, 0 failed
progress: 12.0 s, 247.5 tps, lat 32.255 ms stddev 44.184, 0 failed
progress: 18.0 s, 264.8 tps, lat 30.166 ms stddev 22.869, 0 failed
progress: 24.0 s, 226.7 tps, lat 35.388 ms stddev 20.199, 0 failed
progress: 30.0 s, 417.2 tps, lat 19.159 ms stddev 14.046, 0 failed
progress: 36.0 s, 355.2 tps, lat 22.484 ms stddev 15.588, 0 failed
progress: 42.0 s, 268.8 tps, lat 29.285 ms stddev 31.888, 0 failed
progress: 48.0 s, 274.8 tps, lat 29.560 ms stddev 28.075, 0 failed
progress: 54.0 s, 295.8 tps, lat 27.048 ms stddev 22.395, 0 failed
progress: 60.0 s, 347.3 tps, lat 22.973 ms stddev 22.828, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 1
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 18127
number of failed transactions: 0 (0.000%)
latency average = 26.465 ms
latency stddev = 24.876 ms
initial connection time = 24.941 ms
tps = 302.105252 (without initial connection time)

real    1m0,079s
user    0m1,089s
sys     0m1,967s
```


### Что изменилось и почему? ###
```console
for i in $words_del ; do grep -e "^$i = " /etc/postgresql/15/main/postgresql.conf.1  ; done
max_connections = 100                   # (change requires restart)
shared_buffers = 128MB                  # min 128kB
min_wal_size = 80MB
max_wal_size = 1GB
```


|**параметр**|**before**|**after**|**desc**|
|-|-|-|-|
|max_connections|100|40|Sets the maximum number of client connections that this server will accept.|
|shared_buffers|128MB|1GB|Sets the number of shared buffers for use by the server processes.|
|effective_cache_size|4GB|3GB|Tells the PostgreSQL query planner how much RAM is estimated to be available for caching data|
|maintenance_work_mem|64MB|512MB|Sets the limit for the amount that autovacuum, manual vacuum, bulk index build and other maintenance routines are permitted to use.|
|checkpoint_completion_target|0.9|0.9|Defines the fraction of one checkpoint_interval over which to spread checkpoints. The default value works for most users.|
|wal_buffers|4MB|16MB|The amount of shared memory used for WAL data that has not yet been written to disk. The default setting of -1 selects a size equal to 1/32nd (about 3%) of shared_buffers, but not less than 64kB nor more than the size of one WAL segment, typically 16MB. On very busy, high-core machines it can be useful to raise this to as much as 128MB.|
|default_statistics_target|100|500|Sets the default statistics target. Larger values increase the time needed to do ANALYZE, but might improve the quality of the planner's estimates. Most applications can use the default of 100. For very small/simple databases, decrease to 10 or 50. Data warehousing applications generally need to use 500 to 1000. Otherwise, increase statistics targets on a per-column basis.|
|random_page_cost|4|4|Sets the planner's estimate of the cost of a nonsequentially fetched disk page. Random access to mechanical disk storage is normally much more expensive than four times sequential access. However, a lower default is used (4.0) because the majority of random accesses to disk, such as indexed reads, are assumed to be in cache.|
|effective_io_concurrency|1|2|Number of simultaneous requests that can be handled efficiently by the disk subsystem. SSDs and other memory-based storage can often process many concurrent requests, so the best value might be in the hundreds.|
|work_mem|4MB|6553kB|maximum memory to be used for query workspaces. This limit acts as a primitive resource control, preventing the server from going into swap due to overallocation. Note that this is non-shared RAM per operation, which means large complex queries can use multple times this amount.|
|min_wal_size|80MB|4GB|Sets the minimum size to shrink the WAL to|
|[max_wal_size](https://postgresqlco.nf/doc/en/param/max_wal_size/)|1GB|16GB|Sets the WAL size that triggers a checkpoint|

### Попробую менять по параметру за раз и оценить вклад... и посмотрю что получится при моих настройках ###
* общая разница 40 транзакций
* если конфиг вообще без параметров из новой конфигурации и старой, то  274 - возможно postgres слишком ограничили в пакете... или это в пределах погрешности.
* max_connections - 299-262=37
* shared_buffers - 320-262=59
* effective_cache_size - более аккуратно сказали сколько памяти готовы дать на кэш . 300-262=38
* maintenance_work_mem - влияет только на обслуживание ... влияние vacuum тут низкое. 238 - даже почему от упала, возможно стало меньше памяти для кэша
* wal_buffers -  только с ним 276-262=14 - влияние незначительное, т.к. диск достаточно быстрый, а изменений в базе немного
* effective_io_concurrency - если только с ней, то 282tps - т.е. дает эффект 20 транзакций
* work_mem - в целом незначительно - ведь по умолчанию 4Мб - от 6Мб отличие небольшое. 273-262=11 . А если увеличить в 5 раз до 20мб, то 304-262=42 
* min_wal_size - тпс 249 - стало даже хуже - но в целом незначительно -13. В данном случае возможно выделение лишних ресурсов возможно тоже стоит времени
* max_wal_size - 328-262=66 - вероятно т.к. более эффективно использует ресурсы диска и памяти именно на этой команде тестирования

В целом скорее нет эффекта, так как размеры таблицы - может целиком записать в память... Плюс возможно специально настраивали так в пакете, чтобы успешно проходил такой тест...

добавил данные около 1 млн строк `insert into pgbench_accounts select 100000+row_number() over(partition by null order by null) as rn, 1 as y, null::integer as z, c1 from testnm.t1 ;`
```
scaling factor: 1
query mode: simple
number of clients: 20
number of threads: 1
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 17810
number of failed transactions: 0 (0.000%)
latency average = 67.413 ms
latency stddev = 53.542 ms
initial connection time = 70.814 ms
tps = 295.865734 (without initial connection time)
```
ребутаю кластер, комментирую строки из прикрепленного файла
tps = 280 - даже выше..., меняю на изначальный ребутаю 298 ... т.е. в пределах погрешности
 Получается - плюс минус тоже самое.


 - [x] Создать таблицу с текстовым полем и заполнить случайными или сгенерированными данным в размере 1млн строк
 создал, см выше - даже 2 шт
 - [x] Посмотреть размер файла с таблицей
```console
testdb=# SELECT pg_size_pretty(pg_total_relation_size('testnm.t1'));
 pg_size_pretty
----------------
 50 MB
(1 строка)
```
 - [x] 5 раз обновить все строчки и добавить к каждой строчке любой символ
```console
testdb=# update testnm.t1 set c1=c1||chr((30+10*random())::int4) where true;
UPDATE 1000000
testdb=# update testnm.t1 set c1=c1||chr((30+10*random())::int4) where true;
UPDATE 1000000
testdb=# update testnm.t1 set c1=c1||chr((30+10*random())::int4) where true;
UPDATE 1000000
testdb=# update testnm.t1 set c1=c1||chr((30+10*random())::int4) where true;
UPDATE 1000000
testdb=# update testnm.t1 set c1=c1||chr((30+10*random())::int4) where true;
UPDATE 1000000
```
 - [x] Посмотреть количество мертвых строчек в таблице и когда последний раз приходил автовакуум
```
testdb=# SELECT relname, n_live_tup, n_dead_tup, trunc(100*n_dead_tup/(n_live_tup+1))::float "ratio%", last_autovacuum FROM pg_stat_user_TABLEs WHERE relname = 't1';
 relname | n_live_tup | n_dead_tup | ratio% |        last_autovacuum
---------+------------+------------+--------+-------------------------------
 t1      |    1000000 |    3998949 |    399 | 2023-10-31 01:59:46.949141+03
(1 строка)

```
 - [x] Подождать некоторое время, проверяя, пришел ли автовакуум
```console
testdb=# SELECT relname, n_live_tup, n_dead_tup, trunc(100*n_dead_tup/(n_live_tup+1))::float "ratio%", last_autovacuum FROM pg_stat_user_TABLEs WHERE relname = 't1';
 relname | n_live_tup | n_dead_tup | ratio% |        last_autovacuum
---------+------------+------------+--------+-------------------------------
 t1      |     999991 |          0 |      0 | 2023-10-31 02:00:45.945848+03
```

 - [x] 5 раз обновить все строчки и добавить к каждой строчке любой символ
```sql
begin; update testnm.t1 set c1=c1||'1' where true;update testnm.t1 set c1=c1||'2' where true;update testnm.t1 set c1=c1||'3' where true;update testnm.t1 set c1=c1||'4' where true;update testnm.t1 set c1=c1||'5' where true; commit;
```
```console
BEGIN
UPDATE 1000000

UPDATE 1000000
UPDATE 1000000
UPDATE 1000000
UPDATE 1000000
COMMIT
testdb=#
```
 - [x] Посмотреть размер файла с таблицей
```console
testdb=# SELECT pg_size_pretty(pg_total_relation_size('testnm.t1'));
 pg_size_pretty
----------------
 477 MB
(1 строка)
```
 - [x] Отключить Автовакуум на конкретной таблице
```sql
ALTER TABLE testnm.t1 SET (autovacuum_enabled = off);
```
 - [x] 10 раз обновить все строчки и добавить к каждой строчке любой символ
```sql
begin; update testnm.t1 set c1=c1||'1' where true;update testnm.t1 set c1=c1||'2' where true;update testnm.t1 set c1=c1||'3' where true;update testnm.t1 set c1=c1||'4' where true;update testnm.t1 set c1=c1||'5' where true; update testnm.t1 set c1=c1||'6' where true;update testnm.t1 set c1=c1||'7' where true;update testnm.t1 set c1=c1||'8' where true;update testnm.t1 set c1=c1||'9' where true;update testnm.t1 set c1=c1||'A' where true; commit;
```
 - [x] Посмотреть размер файла с таблицей
```console
SELECT pg_size_pretty(pg_total_relation_size('testnm.t1'));
 pg_size_pretty
----------------
 742 MB
(1 строка)

SELECT relname, n_live_tup, n_dead_tup, trunc(100*n_dead_tup/(n_live_tup+1))::float "ratio%", last_autovacuum FROM pg_stat_user_TABLEs WHERE relname = 't1';
 relname | n_live_tup | n_dead_tup | ratio% |      last_autovacuum
---------+------------+------------+--------+----------------------------
 t1      |     983546 |   10000000 |   1016 | 2023-10-31 02:05:49.179+03
```
### Объясните полученный результат - _Не забудьте включить автовакуум)_ - ###

#### Так как автовакуум отключен - не особождаются занятые кортежи их намного больше чем актуальных ####
```console
testdb=# vacuum verbose  testnm.t1 ;
ИНФОРМАЦИЯ:  очистка "testdb.testnm.t1"
ИНФОРМАЦИЯ:  закончена очистка "testdb.testnm.t1": сканирований индекса: 0
страниц удалено: 0, осталось: 94937, просканировано: 94937 (100.00% от общего числа)
версий строк: удалено: 10000000, осталось: 1000000, «мёртвых», но ещё не подлежащих удалению: 0
XID отсечки удаления: 542195, на момент завершения операции он имел возраст: 0 XID
новое значение relfrozenxid: 542194, оно продвинулось вперёд от предыдущего значения на 3 XID
сканирование индекса не требуется: на страницах таблицы (85592, 90.16% от общего числа) удалено мёртвых идентификаторов элементов: 9996550
средняя скорость чтения: 22.655 МБ/с, средняя скорость записи: 25.323 МБ/с
использование буфера: попаданий: 111155, промахов: 78757, «грязных» записей: 88029
использование WAL: записей: 266122, полных образов страниц: 82297, байт: 76029512
нагрузка системы: CPU: пользов.: 1.20 с, система: 0.81 с, прошло: 27.17 с
ИНФОРМАЦИЯ:  очистка "testdb.pg_toast.pg_toast_16386"
ИНФОРМАЦИЯ:  закончена очистка "testdb.pg_toast.pg_toast_16386": сканирований индекса: 0
страниц удалено: 0, осталось: 0, просканировано: 0 (100.00% от общего числа)
версий строк: удалено: 0, осталось: 0, «мёртвых», но ещё не подлежащих удалению: 0
XID отсечки удаления: 542195, на момент завершения операции он имел возраст: 0 XID
новое значение relfrozenxid: 542195, оно продвинулось вперёд от предыдущего значения на 541469 XID
сканирование индекса не требуется: на страницах таблицы (0, 100.00% от общего числа) удалено мёртвых идентификаторов элементов: 0
средняя скорость чтения: 0.286 МБ/с, средняя скорость записи: 0.000 МБ/с
использование буфера: попаданий: 3, промахов: 1, «грязных» записей: 0
использование WAL: записей: 1, полных образов страниц: 0, байт: 188
нагрузка системы: CPU: пользов.: 0.01 с, система: 0.00 с, прошло: 0.02 с
VACUUM
```
```sql
ALTER TABLE testnm.t1 SET (autovacuum_enabled = on);
```

```console
testdb=# select count(*) from testnm.t1 ;
  count
---------
 1000000
(1 строка)

testdb=# SELECT relname, n_live_tup, n_dead_tup, trunc(100*n_dead_tup/(n_live_tup+1))::float "ratio%", last_autovacuum FROM pg_stat_user_TABLEs WHERE relname = 't1';
 relname | n_live_tup | n_dead_tup | ratio% |      last_autovacuum
---------+------------+------------+--------+----------------------------
 t1      |    1000000 |          0 |      0 | 2023-10-31 02:05:49.179+03
(1 строка)
```
Видно что таблица стала медленее, т.к. автовакуум еще делает analyze [autovacuum_analyze_threshold](https://postgrespro.ru/docs/postgresql/9.6/runtime-config-autovacuum)

после analyze или vacuum analyze - скорость обращения к таблицы стала намного выше.
```console
testdb=# vacuum analyse testnm.t1;
VACUUM
testdb=# select count(*) from testnm.t1 ;
  count
---------
 1000000
(1 строка)
```


 - [x] ✵ Написать анонимную процедуру, в которой в цикле 10 раз обновятся все строчки в искомой таблице. Не забыть вывести номер шага цикла.

```sql
CREATE or REPLACE PROCEDURE test_update10x_t1()
language plpgsql
as $$
declare
x int4 default 1;
begin
for x in 1..10 loop
 update testnm.t1 set c1=c1||x ;
 RAISE debug '%', x ;
 end loop;
end; $$;
```

