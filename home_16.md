# Домашнее задание "Работа с индексами" #
#### Цель: знать и уметь применять основные виды индексов PostgreSQL ;  строить и анализировать план выполнения запроса ; уметь оптимизировать запросы для с использованием индексов . ####
#### инструкция: Создать индексы на БД, которые ускорят доступ к данным. ####
#### В данном задании тренируются навыки: определения узких мест ; написания запросов для создания индекса ; оптимизации . ####

- [x] Создать индекс к какой-либо из таблиц вашей БД
```sh
# создаем сеть, подсеть и машину. получаем адреса. настраиваем. ставим демо базу https://habr.com/ru/companies/postgrespro/articles/316428/
yc vpc network create --name testnetb; yc vpc subnet create --network-name testnetb --name subnetb --zone 'ru-central1-b' --range '10.0.130.0/24'
nam=p1; yc compute instance create --name $nam --metadata-from-file user-data=meta.yaml --create-boot-disk name=root-disk2-$nam,type=network-ssd,size=20G,auto-delete,image-folder-id=standard-images,image-family=ubuntu-2204-lts --memory 4G --cores 2 --hostname u$nam --metadata serial-port-enable=1 --zone ru-central1-b --core-fraction 50 --preemptible --platform standard-v2; yc compute instance add-one-to-one-nat $nam --network-interface-index 0
mip=`curl -s https://ipinfo.io/json|jq .ip|sed 's/"//g'`
hostip=`yc --format json compute instance list  |  jq '.[] | .network_interfaces[0].primary_v4_address.one_to_one_nat.address ' |sed 's/"//g'`
sleep 5m
ssh -o "VerifyHostKeyDNS no" -i .ssh/yc_serialssh_key uuu@$hostip "sudo apt install firewalld p7zip-full zip -y ; sudo firewall-cmd --zone=work --add-source=$mip --permanent ; sudo firewall-cmd --zone=work --add-source=10.0.130.0/24 --permanent ; sudo firewall-cmd --zone=work --add-port=5432/tcp --permanent;sudo firewall-cmd --reload ; sudo -u postgres psql -c \"alter role postgres password 'test123Rs'\" ; sudo -u postgres psql -c \"alter system set listen_addresses='*' \" ; sudo -u postgres psql -c \"alter system set wal_level=logical \" ; echo -e \"host    all     all             $mip/32                 scram-sha-256\\nhost    replication     all     10.0.130.0/24                 scram-sha-256\nhost    all     all             10.0.130.0/24                 scram-sha-256\" | sudo tee -a /etc/postgresql/15/main/pg_hba.conf ; sudo systemctl restart postgresql@15-main "
export PGPASSWORD=test123Rs
ssh -o "VerifyHostKeyDNS no" -i .ssh/yc_serialssh_key uuu@$hostip <<EOF
sudo apt clean all
sudo -i -u postgres
wget https://edu.postgrespro.ru/demo-big-20161013.zip
7za x demo-big-20161013.zip -so demo_big.sql|psql -f -
psql -c "alter system set synchronous_commit = off;"
psql -c "select pg_reload_conf();"
psql demo -c 'alter database demo set search_path=bookings, postgres'
psql demo -c "\dt+"
rm demo-big-20161013.zip
EOF
```
```console
psql demo -c "\dt+"
                                             Список отношений
  Схема   |       Имя       |   Тип   | Владелец |  Хранение  | Метод доступа | Размер |     Описание
----------+-----------------+---------+----------+------------+---------------+--------+-------------------
 bookings | aircrafts       | таблица | postgres | постоянное | heap          | 16 kB  | Самолеты
 bookings | airports        | таблица | postgres | постоянное | heap          | 48 kB  | Аэропорты
 bookings | boarding_passes | таблица | postgres | постоянное | heap          | 455 MB | Посадочные талоны
 bookings | bookings        | таблица | postgres | постоянное | heap          | 105 MB | Бронирования
 bookings | flights         | таблица | postgres | постоянное | heap          | 21 MB  | Рейсы
 bookings | seats           | таблица | postgres | постоянное | heap          | 96 kB  | Места
 bookings | ticket_flights  | таблица | postgres | постоянное | heap          | 547 MB | Перелеты
 bookings | tickets         | таблица | postgres | постоянное | heap          | 386 MB | Билеты
(8 строк)
```

- [x] Прислать текстом результат команды explain, в которой используется данный индекс
```sh
psql << EOF
create index ticket_flights_fare_condition on ticket_flights(fare_conditions);
comment on index ticket_flights_fare_condition is 'btree test';
explain select fare_conditions, count(*) from ticket_flights group by fare_conditions;
explain (analyze,buffers, timing) select fare_conditions, count(*) from ticket_flights group by fare_conditions;
select fare_conditions, count(*) from ticket_flights group by fare_conditions;
select relid,indexrelid,schemaname,relname,indexrelname,idx_scan,idx_tup_read,idx_tup_fetch from pg_catalog.pg_stat_user_indexes where indexrelname ='ticket_flights_fare_condition';
select schemaname,tablename,indexname,"tablespace",indexdef from pg_catalog.pg_indexes where indexname ='ticket_flights_fare_condition';
explain (analyze,buffers, timing) select fare_conditions, count(*) from ticket_flights where fare_conditions like 'Bus%' group by fare_conditions;
explain (analyze,buffers, timing) select fare_conditions, count(*) from ticket_flights where fare_conditions like '%us%' group by fare_conditions;
EOF
```console
CREATE INDEX
                                                                  QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=1000.46..123861.58 rows=3 width=16)
   Group Key: fare_conditions
   ->  Gather Merge  (cost=1000.46..123861.52 rows=6 width=16)
         Workers Planned: 2
         ->  Partial GroupAggregate  (cost=0.43..122860.80 rows=3 width=16)
               Group Key: fare_conditions
               ->  Parallel Index Only Scan using ticket_flights_fare_condition on ticket_flights  (cost=0.43..105377.75 rows=3496605 width=8)
 JIT:
   Functions: 6
   Options: Inlining false, Optimization false, Expressions true, Deforming true
(10 строк)


                                                                                           QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=1000.46..123861.58 rows=3 width=16) (actual time=828.310..836.281 rows=3 loops=1)
   Group Key: fare_conditions
   Buffers: shared hit=7090
   ->  Gather Merge  (cost=1000.46..123861.52 rows=6 width=16) (actual time=828.054..836.223 rows=8 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=7090
         ->  Partial GroupAggregate  (cost=0.43..122860.80 rows=3 width=16) (actual time=99.671..551.494 rows=3 loops=3)
               Group Key: fare_conditions
               Buffers: shared hit=7090
               ->  Parallel Index Only Scan using ticket_flights_fare_condition on ticket_flights  (cost=0.43..105377.75 rows=3496605 width=8) (actual time=0.055..258.586 rows=2797284 loops=3)
                     Heap Fetches: 0
                     Buffers: shared hit=7090
 Planning Time: 0.108 ms
 JIT:
   Functions: 12
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 1.294 ms, Inlining 0.000 ms, Optimization 0.649 ms, Emission 21.556 ms, Total 23.498 ms
 Execution Time: 836.841 ms
(19 строк)


 fare_conditions |  count
-----------------+---------
 Business        |  859656
 Comfort         |  139965
 Economy         | 7392231
(3 строки)


 relid | indexrelid | schemaname |    relname     |         indexrelname          | idx_scan | idx_tup_read | idx_tup_fetch
-------+------------+------------+----------------+-------------------------------+----------+--------------+---------------
 16432 |      16512 | bookings   | ticket_flights | ticket_flights_fare_condition |        3 |      8391852 |             0
(1 строка)

 schemaname |   tablename    |           indexname           | tablespace |                                              indexdef
------------+----------------+-------------------------------+------------+-----------------------------------------------------------------------------------------------------
 bookings   | ticket_flights | ticket_flights_fare_condition |            | CREATE INDEX ticket_flights_fare_condition ON bookings.ticket_flights USING btree (fare_conditions)
(1 строка


                                                                                          QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=1000.46..116994.82 rows=3 width=16) (actual time=463.268..468.178 rows=1 loops=1)
   Group Key: fare_conditions
   Buffers: shared hit=7092
   ->  Gather Merge  (cost=1000.46..116994.76 rows=6 width=16) (actual time=463.247..468.156 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=7092
         ->  Partial GroupAggregate  (cost=0.43..115994.05 rows=3 width=16) (actual time=417.606..417.608 rows=1 loops=3)
               Group Key: fare_conditions
               Buffers: shared hit=7092
               ->  Parallel Index Only Scan using ticket_flights_fare_condition on ticket_flights  (cost=0.43..114119.26 rows=374952 width=8) (actual time=8.679..382.390 rows=286552 loops=3)
                     Filter: ((fare_conditions)::text ~~ 'Bus%'::text)
                     Rows Removed by Filter: 2510732
                     Heap Fetches: 0
                     Buffers: shared hit=7092
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.152 ms
 JIT:
   Functions: 15
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 1.432 ms, Inlining 0.000 ms, Optimization 0.673 ms, Emission 13.165 ms, Total 15.270 ms
 Execution Time: 468.854 ms
(23 строки)


                                                                                          QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=1000.46..116994.82 rows=3 width=16) (actual time=929.260..936.271 rows=1 loops=1)
   Group Key: fare_conditions
   Buffers: shared hit=7092
   ->  Gather Merge  (cost=1000.46..116994.76 rows=6 width=16) (actual time=929.233..936.242 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=7092
         ->  Partial GroupAggregate  (cost=0.43..115994.05 rows=3 width=16) (actual time=874.584..874.586 rows=1 loops=3)
               Group Key: fare_conditions
               Buffers: shared hit=7092
               ->  Parallel Index Only Scan using ticket_flights_fare_condition on ticket_flights  (cost=0.43..114119.26 rows=374952 width=8) (actual time=8.258..802.276 rows=286552 loops=3)
                     Filter: ((fare_conditions)::text ~~ '%us%'::text)
                     Rows Removed by Filter: 2510732
                     Heap Fetches: 0
                     Buffers: shared hit=7092
 Planning Time: 0.123 ms
 JIT:
   Functions: 15
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 1.601 ms, Inlining 0.000 ms, Optimization 0.728 ms, Emission 23.985 ms, Total 26.314 ms
 Execution Time: 936.910 ms
(21 строка)
```
btree - б-дерево подходит для операций >,<,>=,=,<= и потому и для сортировки - поэтому отлично себя показывает ... для чисел, дат, условий like заканчивающихся на % - т.е отчасти и для полнотекстового поиска.
    правда с рядом ограничений. Зато с помощью include можно добавлять колонки - чтобы ускорить чтение связанных данных к примеру.
    Занимает приличный размер. Поэтому постгрес оценивает - по размеру индекса - целесообразно ли его вообще использовать.

```sql
select schemaname as sm,tablename as tab,indexname,
/*"tablespace"ts,*/ indexdef,pg_size_pretty(pg_relation_size(indexname::varchar(1000)))as zi,
pg_size_pretty(pg_table_size(tablename::varchar(1000)))as zt,
/*pg_size_pretty(pg_indexes_size(tablename::varchar(1000)))as zi_a,*/
pg_size_pretty(pg_total_relation_size(tablename::varchar(1000)))as z_total
from pg_catalog.pg_indexes i where tablename='ticket_flights';
```
```console
demo=# select schemaname as sm,tablename as tab,indexname,"tablespace"ts,indexdef,pg_size_pretty(pg_indexes_size(indexname::varchar(1000)))as zi, pg_size_pretty(pg_table_size(tablename::varchar(1000)))as zt from pg_catalog.pg_indexes i where tablename='ticket_flights';
    sm    |      tab       |           indexname           |                                               indexdef                                                |   zi   |   zt   | z_total
----------+----------------+-------------------------------+-------------------------------------------------------------------------------------------------------+--------+--------+---------
 bookings | ticket_flights | ticket_flights_pkey           | CREATE UNIQUE INDEX ticket_flights_pkey ON bookings.ticket_flights USING btree (ticket_no, flight_id) | 325 MB | 547 MB | 927 MB
 bookings | ticket_flights | ticket_flights_fare_condition | CREATE INDEX ticket_flights_fare_condition ON bookings.ticket_flights USING btree (fare_conditions)   | 56 MB  | 547 MB | 927 MB
(2 строки)
```

Можно использовать частичный индекс:
```sql
drop index ticket_flights_fare_condition;
create index ticket_flights_fare_condition on ticket_flights(fare_conditions) where fare_conditions!='Economy';
comment on index ticket_flights_fare_condition is 'btree partial test';
```

|sm|tab|indexname|indexdef|zi|zt|z_total|
|--|---|---------|--------|--|--|-------|
|bookings|ticket_flights|ticket_flights_pkey|CREATE UNIQUE INDEX ticket_flights_pkey ON bookings.ticket_flights USING btree (ticket_no, flight_id)|325 MB|547 MB|878 MB|
|bookings|ticket_flights|ticket_flights_fare_condition|CREATE INDEX ticket_flights_fare_condition ON bookings.ticket_flights USING btree (fare_conditions) WHERE ((fare_conditions)::text <> 'Economy'::text)|6888 kB|547 MB|878 MB|

что дает приличную экономию места и ускорение:
```sql
explain (analyze,buffers, timing) select fare_conditions, count(*) from ticket_flights where fare_conditions like 'Bus%' group by fare_conditions;
```
```
|QUERY PLAN                                                                                                                                               |
|---------------------------------------------------------------------------------------------------------------------------------------------------------|
|Finalize GroupAggregate  (cost=116390.69..116391.45 rows=3 width=16) (actual time=573.376..576.642 rows=1 loops=1)                                       |
|  Group Key: fare_conditions                                                                                                                             |
|  Buffers: shared hit=326 read=69623                                                                                                                     |
|  ->  Gather Merge  (cost=116390.69..116391.39 rows=6 width=16) (actual time=573.356..576.621 rows=3 loops=1)                                            |
|        Workers Planned: 2                                                                                                                               |
|        Workers Launched: 2                                                                                                                              |
|        Buffers: shared hit=326 read=69623                                                                                                               |
|        ->  Sort  (cost=115390.67..115390.67 rows=3 width=16) (actual time=522.907..522.909 rows=1 loops=3)                                              |
|              Sort Key: fare_conditions                                                                                                                  |
|              Sort Method: quicksort  Memory: 25kB                                                                                                       |
|              Buffers: shared hit=326 read=69623                                                                                                         |
|              Worker 0:  Sort Method: quicksort  Memory: 25kB                                                                                            |
|              Worker 1:  Sort Method: quicksort  Memory: 25kB                                                                                            |
|              ->  Partial HashAggregate  (cost=115390.61..115390.64 rows=3 width=16) (actual time=522.856..522.857 rows=1 loops=3)                       |
|                    Group Key: fare_conditions                                                                                                           |
|                    Batches: 1  Memory Usage: 24kB                                                                                                       |
|                    Buffers: shared hit=310 read=69623                                                                                                   |
|                    Worker 0:  Batches: 1  Memory Usage: 24kB                                                                                            |
|                    Worker 1:  Batches: 1  Memory Usage: 24kB                                                                                            |
|                    ->  Parallel Seq Scan on ticket_flights  (cost=0.00..113640.56 rows=350010 width=8) (actual time=10.529..457.743 rows=286552 loops=3)|
|                          Filter: ((fare_conditions)::text ~~ 'Bus%'::text)                                                                              |
|                          Rows Removed by Filter: 2510732                                                                                                |
|                          Buffers: shared hit=310 read=69623                                                                                             |
|Planning:                                                                                                                                                |
|  Buffers: shared hit=12 read=1                                                                                                                          |
|Planning Time: 0.397 ms                                                                                                                                  |
|JIT:                                                                                                                                                     |
|  Functions: 27                                                                                                                                          |
|  Options: Inlining false, Optimization false, Expressions true, Deforming true                                                                          |
|  Timing: Generation 2.138 ms, Inlining 0.000 ms, Optimization 1.105 ms, Emission 29.541 ms, Total 32.784 ms                                             |
|Execution Time: 577.486 ms                                                                                                                               |
```
```console
explain (analyze,buffers, timing) select fare_conditions, count(*) from ticket_flights group by fare_conditions;
                                                                         QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=123382.15..123382.91 rows=3 width=16) (actual time=1301.954..1303.066 rows=3 loops=1)
   Group Key: fare_conditions
   Buffers: shared hit=518 read=69431
   ->  Gather Merge  (cost=123382.15..123382.85 rows=6 width=16) (actual time=1301.898..1303.010 rows=9 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=518 read=69431
         ->  Sort  (cost=122382.13..122382.14 rows=3 width=16) (actual time=1256.964..1256.966 rows=3 loops=3)
               Sort Key: fare_conditions
               Sort Method: quicksort  Memory: 25kB
               Buffers: shared hit=518 read=69431
               Worker 0:  Sort Method: quicksort  Memory: 25kB
               Worker 1:  Sort Method: quicksort  Memory: 25kB
               ->  Partial HashAggregate  (cost=122382.07..122382.10 rows=3 width=16) (actual time=1256.924..1256.927 rows=3 loops=3)
                     Group Key: fare_conditions
                     Batches: 1  Memory Usage: 24kB
                     Buffers: shared hit=502 read=69431
                     Worker 0:  Batches: 1  Memory Usage: 24kB
                     Worker 1:  Batches: 1  Memory Usage: 24kB
                     ->  Parallel Seq Scan on ticket_flights  (cost=0.00..104899.05 rows=3496605 width=8) (actual time=0.033..400.610 rows=2797284 loops=3)
                           Buffers: shared hit=502 read=69431
 Planning:
   Buffers: shared hit=24
 Planning Time: 0.292 ms
 JIT:
   Functions: 21
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 1.633 ms, Inlining 0.000 ms, Optimization 0.918 ms, Emission 32.907 ms, Total 35.458 ms
 Execution Time: 1303.916 ms
(29 строк)
```
Но использование требует знание возможных значений, "нереляционных связей", знания запросов... зато будет обновляться только если обновятся нужные строки


- [x] Реализовать индекс для полнотекстового поиска
Обычно используют GIN или GIST.  GIN выигрывает в точности и скорости поиска у GiST. Если данные изменяются не часто, а искать надо быстро — скорее всего выбор падет на GIN.
```console
drop index ticket_flights_fare_condition;
demo=# create index ticket_flights_fare_condition_gin on ticket_flights USING gin (cast(fare_conditions as tsvector));
CREATE INDEX
demo=# explain (analyze,buffers, timing)  select fare_conditions, count(*) from ticket_flights where 'Bus' @@ fare_conditions::tsvector group by fare_conditions;
                                                                      QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------------------------------
 HashAggregate  (cost=66069.32..66069.35 rows=3 width=16) (actual time=0.012..0.013 rows=0 loops=1)
   Group Key: fare_conditions
   Batches: 1  Memory Usage: 24kB
   Buffers: shared hit=2
   ->  Bitmap Heap Scan on ticket_flights  (cost=1801.18..65859.52 rows=41959 width=8) (actual time=0.010..0.010 rows=0 loops=1)
         Recheck Cond: ('''Bus'''::tsquery @@ (fare_conditions)::tsvector)
         Buffers: shared hit=2
         ->  Bitmap Index Scan on ticket_flights_fare_condition_gin  (cost=0.00..1790.69 rows=41959 width=0) (actual time=0.008..0.008 rows=0 loops=1)
               Index Cond: ((fare_conditions)::tsvector @@ '''Bus'''::tsquery)
               Buffers: shared hit=2
 Planning:
   Buffers: shared hit=26 read=3
 Planning Time: 0.363 ms
 Execution Time: 0.076 ms
(14 строк)comment on index ticket_flights_fare_condition is 'btree gin';
```

-- видно что в разы меньше размер ( 8840 kB )


попробуем еще это:
```sql
create extension pg_trgm;
drop index ticket_flights_fare_condition;
create index ticket_flights_fare_condition on ticket_flights using gist( fare_conditions GiST_trgm_ops ) ;
comment on index ticket_flights_fare_condition is 'test GiST_trgm_ops'
```
|sm|tab|indexname|indexdef|zi|zt|z_total|
|--|---|---------|--------|--|--|-------|
|bookings|ticket_flights|ticket_flights_pkey|CREATE UNIQUE INDEX ticket_flights_pkey ON bookings.ticket_flights USING btree (ticket_no, flight_id)|570 MB|547 MB|1905 MB|
|bookings|ticket_flights|ticket_flights_fare_condition|CREATE INDEX ticket_flights_fare_condition ON bookings.ticket_flights USING gist (fare_conditions gist_trgm_ops)|788 MB|547 MB|1905 MB|


великолепно:
```console
demo=# explain (analyze,buffers, timing) select fare_conditions, count(*) from ticket_flights where fare_conditions like 'Comfor%' group by fare_conditions;
                                                                                 QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=102737.44..102738.20 rows=3 width=16) (actual time=124.432..128.407 rows=1 loops=1)
   Group Key: fare_conditions
   Buffers: shared hit=17 read=2843
   ->  Gather Merge  (cost=102737.44..102738.14 rows=6 width=16) (actual time=124.382..128.357 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=17 read=2843
         ->  Sort  (cost=101737.42..101737.43 rows=3 width=16) (actual time=62.612..62.615 rows=1 loops=3)
               Sort Key: fare_conditions
               Sort Method: quicksort  Memory: 25kB
               Buffers: shared hit=17 read=2843
               Worker 0:  Sort Method: quicksort  Memory: 25kB
               Worker 1:  Sort Method: quicksort  Memory: 25kB
               ->  Partial HashAggregate  (cost=101737.37..101737.40 rows=3 width=16) (actual time=62.570..62.572 rows=1 loops=3)
                     Group Key: fare_conditions
                     Batches: 1  Memory Usage: 24kB
                     Buffers: shared read=2842
                     Worker 0:  Batches: 1  Memory Usage: 24kB
                     Worker 1:  Batches: 1  Memory Usage: 24kB
                     ->  Parallel Bitmap Heap Scan on ticket_flights  (cost=7933.71..101441.32 rows=59209 width=8) (actual time=30.693..49.366 rows=46655 loops=3)
                           Recheck Cond: ((fare_conditions)::text ~~ 'Comfor%'::text)
                           Heap Blocks: exact=1003
                           Buffers: shared read=2842
                           ->  Bitmap Index Scan on ticket_flights_fare_condition  (cost=0.00..7898.18 rows=142102 width=0) (actual time=38.082..38.082 rows=139965 loops=1)
                                 Index Cond: ((fare_conditions)::text ~~ 'Comfor%'::text)
                                 Buffers: shared read=1675
 Planning:
   Buffers: shared hit=11 read=9 dirtied=4
 Planning Time: 0.353 ms
 JIT:
   Functions: 27
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 2.499 ms, Inlining 0.000 ms, Optimization 1.447 ms, Emission 52.247 ms, Total 56.192 ms
 Execution Time: 129.350 ms
(34 строки)


demo=# explain (analyze,buffers, timing) select fare_conditions, count(*) from ticket_flights where fare_conditions like '%omfor%' group by fare_conditions;
                                                                                 QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=102737.44..102738.20 rows=3 width=16) (actual time=132.330..133.331 rows=1 loops=1)
   Group Key: fare_conditions
   Buffers: shared hit=2860
   ->  Gather Merge  (cost=102737.44..102738.14 rows=6 width=16) (actual time=132.238..133.240 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=2860
         ->  Sort  (cost=101737.42..101737.43 rows=3 width=16) (actual time=64.175..64.179 rows=1 loops=3)
               Sort Key: fare_conditions
               Sort Method: quicksort  Memory: 25kB
               Buffers: shared hit=2860
               Worker 0:  Sort Method: quicksort  Memory: 25kB
               Worker 1:  Sort Method: quicksort  Memory: 25kB
               ->  Partial HashAggregate  (cost=101737.37..101737.40 rows=3 width=16) (actual time=64.113..64.116 rows=1 loops=3)
                     Group Key: fare_conditions
                     Batches: 1  Memory Usage: 24kB
                     Buffers: shared hit=2842
                     Worker 0:  Batches: 1  Memory Usage: 24kB
                     Worker 1:  Batches: 1  Memory Usage: 24kB
                     ->  Parallel Bitmap Heap Scan on ticket_flights  (cost=7933.71..101441.32 rows=59209 width=8) (actual time=28.582..45.215 rows=46655 loops=3)
                           Recheck Cond: ((fare_conditions)::text ~~ '%omfor%'::text)
                           Heap Blocks: exact=1028
                           Buffers: shared hit=2842
                           ->  Bitmap Index Scan on ticket_flights_fare_condition  (cost=0.00..7898.18 rows=142102 width=0) (actual time=31.064..31.065 rows=139965 loops=1)
                                 Index Cond: ((fare_conditions)::text ~~ '%omfor%'::text)
                                 Buffers: shared hit=1675
 Planning Time: 0.145 ms
 JIT:
   Functions: 27
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 2.942 ms, Inlining 0.000 ms, Optimization 1.895 ms, Emission 52.436 ms, Total 57.273 ms
 Execution Time: 134.496 ms
(32 строки)



demo=# explain (analyze,buffers, timing) select fare_conditions, count(*) from ticket_flights where fare_conditions similar to 'Comfor[A-z]' group by fare_conditions;
                                                                                 QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=102737.44..102738.20 rows=3 width=16) (actual time=154.286..154.486 rows=1 loops=1)
   Group Key: fare_conditions
   Buffers: shared hit=2860
   ->  Gather Merge  (cost=102737.44..102738.14 rows=6 width=16) (actual time=154.217..154.419 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=2860
         ->  Sort  (cost=101737.42..101737.43 rows=3 width=16) (actual time=103.430..103.433 rows=1 loops=3)
               Sort Key: fare_conditions
               Sort Method: quicksort  Memory: 25kB
               Buffers: shared hit=2860
               Worker 0:  Sort Method: quicksort  Memory: 25kB
               Worker 1:  Sort Method: quicksort  Memory: 25kB
               ->  Partial HashAggregate  (cost=101737.37..101737.40 rows=3 width=16) (actual time=103.391..103.393 rows=1 loops=3)
                     Group Key: fare_conditions
                     Batches: 1  Memory Usage: 24kB
                     Buffers: shared hit=2842
                     Worker 0:  Batches: 1  Memory Usage: 24kB
                     Worker 1:  Batches: 1  Memory Usage: 24kB
                     ->  Parallel Bitmap Heap Scan on ticket_flights  (cost=7933.71..101441.32 rows=59209 width=8) (actual time=24.464..91.792 rows=46655 loops=3)
                           Recheck Cond: ((fare_conditions)::text ~ '^(?:Comfor[A-z])$'::text)
                           Heap Blocks: exact=720
                           Buffers: shared hit=2842
                           ->  Bitmap Index Scan on ticket_flights_fare_condition  (cost=0.00..7898.18 rows=142102 width=0) (actual time=34.858..34.859 rows=139965 loops=1)
                                 Index Cond: ((fare_conditions)::text ~ '^(?:Comfor[A-z])$'::text)
                                 Buffers: shared hit=1675
 Planning:
   Buffers: shared hit=2 read=1
 Planning Time: 0.198 ms
 JIT:
   Functions: 27
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 2.195 ms, Inlining 0.000 ms, Optimization 1.309 ms, Emission 36.896 ms, Total 40.399 ms
 Execution Time: 155.558 ms
(34 строки)
```
-- но размер индекса на базе триграмм больше, хотя и функциональность выше


- [x] Реализовать индекс на часть таблицы или индекс на поле с функцией
```sql
create index lower_fare_conditions on ticket_flights using brin(lower(fare_conditions));
comment on index lower_fare_conditions is 'partial function index';
explain (analyze,buffers, timing) select fare_conditions, count(*) from ticket_flights where lower(fare_conditions) ='comfort' group by fare_conditions;
```
```console
demo=# explain (analyze,buffers, timing) select fare_conditions, count(*) from ticket_flights where lower(fare_conditions) ='comfort' group by fare_conditions;
                                                                            QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=123513.56..123514.32 rows=3 width=16) (actual time=173.345..173.987 rows=1 loops=1)
   Group Key: fare_conditions
   Buffers: shared hit=1194 read=1393
   ->  Gather Merge  (cost=123513.56..123514.26 rows=6 width=16) (actual time=173.245..173.887 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=1194 read=1393
         ->  Sort  (cost=122513.54..122513.55 rows=3 width=16) (actual time=117.245..117.249 rows=1 loops=3)
               Sort Key: fare_conditions
               Sort Method: quicksort  Memory: 25kB
               Buffers: shared hit=1194 read=1393
               Worker 0:  Sort Method: quicksort  Memory: 25kB
               Worker 1:  Sort Method: quicksort  Memory: 25kB
               ->  Partial HashAggregate  (cost=122513.48..122513.51 rows=3 width=16) (actual time=117.191..117.194 rows=1 loops=3)
                     Group Key: fare_conditions
                     Batches: 1  Memory Usage: 24kB
                     Buffers: shared hit=1176 read=1393
                     Worker 0:  Batches: 1  Memory Usage: 24kB
                     Worker 1:  Batches: 1  Memory Usage: 24kB
                     ->  Parallel Bitmap Heap Scan on ticket_flights  (cost=43.99..122426.07 rows=17483 width=8) (actual time=50.339..100.255 rows=46655 loops=3)
                           Recheck Cond: (lower((fare_conditions)::text) = 'comfort'::text)
                           Rows Removed by Index Recheck: 55745
                           Heap Blocks: lossy=1168
                           Buffers: shared hit=1176 read=1393
                           ->  Bitmap Index Scan on lower_fare_conditions  (cost=0.00..33.50 rows=8391852 width=0) (actual time=0.993..0.994 rows=25600 loops=1)
                                 Index Cond: (lower((fare_conditions)::text) = 'comfort'::text)
                                 Buffers: shared hit=9
 Planning:
   Buffers: shared hit=17 read=2
 Planning Time: 0.329 ms
 JIT:
   Functions: 27
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 2.827 ms, Inlining 0.000 ms, Optimization 1.328 ms, Emission 49.568 ms, Total 53.723 ms
 Execution Time: 175.302 ms
(35 строк)
```

- [x] Создать индекс на несколько полей
```sql
create index lower_fare_conditions on ticket_flights using btree(fare_conditions,amount) ;
drop index lower_fare_conditions;
drop index ticket_flights_fare_condition;
```
|sm|tab|indexname|indexdef|zi|zt|z_total|
|--|---|---------|--------|--|--|-------|
|bookings|ticket_flights|multi_test|CREATE INDEX multi_test ON bookings.ticket_flights USING btree (fare_conditions, amount)|253 MB|547 MB|2158 MB|

```console
demo=# explain (analyze,buffers, timing)  select fare_conditions, count(*) from ticket_flights where fare_conditions ='Comfort' and amount<10000000 group by fare_conditions;
                                                                              QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=1000.56..5502.37 rows=3 width=16) (actual time=53.176..59.377 rows=1 loops=1)
   Group Key: fare_conditions
   Buffers: shared hit=541
   ->  Gather  (cost=1000.56..5502.31 rows=6 width=16) (actual time=42.438..59.362 rows=1 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=541
         ->  Partial GroupAggregate  (cost=0.56..4501.71 rows=3 width=16) (actual time=14.022..14.022 rows=0 loops=3)
               Group Key: fare_conditions
               Buffers: shared hit=541
               ->  Parallel Index Only Scan using multi_test on ticket_flights  (cost=0.56..4205.64 rows=59208 width=8) (actual time=0.016..9.330 rows=46655 loops=3)
                     Index Cond: ((fare_conditions = 'Comfort'::text) AND (amount < '10000000'::numeric))
                     Heap Fetches: 0
                     Buffers: shared hit=541
 Planning Time: 0.151 ms
 Execution Time: 59.425 ms
(16 строк)
```

- [x] Написать комментарии к каждому из индексов
- [x] Описать что и как делали и с какими проблемами столкнулись
большая база... операции занимают время. Остальное - в комментах выше.
