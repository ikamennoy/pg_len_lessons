# Домашнее задание - *Механизм блокировок* #
## Цель: *понимать как работает механизм блокировок объектов и строк* ##
## Описание/Пошаговая инструкция выполнения домашнего задания: ##

- [x] Настройте сервер так, чтобы в журнал сообщений сбрасывалась информация о блокировках, удерживаемых более 200 миллисекунд.
```sh
# берем из home7.md # meta.yaml делаем как тут https://cloudinit.readthedocs.io/en/23.3.3/reference/examples.html
yc compute instance delete --name tu22p; yc compute instance create --name tu22p --metadata-from-file user-data=meta.yaml --create-boot-disk name=root-disk2,type=network-ssd,size=10G,auto-delete,image-folder-id=standard-images,image-family=ubuntu-2204-lts --memory 4G --cores 2 --hostname upgtest --metadata serial-port-enable=1 --zone ru-central1-b --core-fraction 50 --preemptible --platform standard-v2; yc compute instance add-one-to-one-nat tu22p --network-interface-index 0 ; yc compute connect-to-serial-port --instance-name tu22p --ssh-key .ssh/yc_serialssh_key --user uuu
```
```sh
sudo -u postgres psql -c "ALTER SYSTEM SET log_lock_waits = on"
sudo -u postgres psql -c "ALTER SYSTEM SET deadlock_timeout=200"
sudo -u postgres psql -c "SELECT pg_reload_conf();SHOW deadlock_timeout;show log_lock_waits"
```
```console
ALTER SYSTEM
 pg_reload_conf
----------------
 t
(1 строка)

 deadlock_timeout
------------------
 200ms
(1 строка)

 lock_timeout
--------------
 0
(1 строка)

 log_lock_waits
----------------
 on
(1 строка)
```
   >  Воспроизведите ситуацию, при которой в журнале появятся такие сообщения.
```sh
sudo -u postgres psql testdb -c "create table testt as select x from generate_series(10,100)x;" 
sudo -u postgres psql testdb -c "begin;update testt set x=x+100 where x=(select min(x) from testt ) ; SELECT pg_sleep(5) ; commit ; select now(),'one' ;" | cat &  sudo -u postgres psql testdb -c "begin; update testt set x=x+100 where x=(select min(x) from testt ) ; SELECT pg_sleep(1) ; select * from pg_locks ; select max(x) from testt ;  commit; select now(),'two' " | cat &
```

```console
[1] 7250
[2] 7252
BEGIN
UPDATE 1
 pg_sleep
----------

(1 строка)

   locktype    | database | relation | page | tuple | virtualxid | transactionid | classid | objid | objsubid | virtualtransaction | pid  |       mode       | granted | fastpath |           waitstart
---------------+----------+----------+------+-------+------------+---------------+---------+-------+----------+--------------------+------+------------------+---------+----------+-------------------------------
 relation      |    16384 |    12073 |      |       |            |               |         |       |          | 4/23               | 7259 | AccessShareLock  | t       | t        |
 relation      |    16384 |    16396 |      |       |            |               |         |       |          | 4/23               | 7259 | AccessShareLock  | t       | t        |
 relation      |    16384 |    16396 |      |       |            |               |         |       |          | 4/23               | 7259 | RowExclusiveLock | t       | t        |
 virtualxid    |          |          |      |       | 4/23       |               |         |       |          | 4/23               | 7259 | ExclusiveLock    | t       | t        |
 relation      |    16384 |    16396 |      |       |            |               |         |       |          | 3/119              | 7258 | AccessShareLock  | t       | t        |
 relation      |    16384 |    16396 |      |       |            |               |         |       |          | 3/119              | 7258 | RowExclusiveLock | t       | t        |
 virtualxid    |          |          |      |       | 3/119      |               |         |       |          | 3/119              | 7258 | ExclusiveLock    | t       | t        |
 tuple         |    16384 |    16396 |    0 |     2 |            |               |         |       |          | 3/119              | 7258 | ExclusiveLock    | t       | f        |
 transactionid |          |          |      |       |            |           745 |         |       |          | 3/119              | 7258 | ShareLock        | f       | f        | 2023-11-09 02:31:55.050463+03
 transactionid |          |          |      |       |            |           744 |         |       |          | 3/119              | 7258 | ExclusiveLock    | t       | f        |
 transactionid |          |          |      |       |            |           745 |         |       |          | 4/23               | 7259 | ExclusiveLock    | t       | f        |
(11 строк)

 max
-----
 111
(1 строка)

COMMIT
              now              | ?column?
-------------------------------+----------
 2023-11-09 02:31:55.049547+03 | two
(1 строка)

BEGIN
UPDATE 0
 pg_sleep
----------

(1 строка)

COMMIT
              now              | ?column?
-------------------------------+----------
 2023-11-09 02:31:55.049129+03 | one
(1 строка)

[1]-  Done                    sudo -u postgres psql testdb -c "begin;update testt set x=x+100 where x=(select min(x) from testt ) ; SELECT pg_sleep(5) ; commit ; select now(),'one' ;" | cat
[2]+  Done                    sudo -u postgres psql testdb -c "begin; update testt set x=x+100 where x=(select min(x) from testt ) ; SELECT pg_sleep(1) ; select * from pg_locks ; select max(x) from testt ;  commit; select now(),'two' " | cat

```

```console
sudo tail -n 2 /var/log/postgresql/postgresql-15-main.log
2023-11-09 02:31:55.250 MSK [7258] postgres@testdb СООБЩЕНИЕ:  процесс 7258 продолжает ожидать в режиме ShareLock блокировку "транзакция 745" в течение 200.101 мс
2023-11-09 02:31:55.250 MSK [7258] postgres@testdb ПОДРОБНОСТИ:  Process holding the lock: 7259. Wait queue: 7258.
2023-11-09 02:31:55.250 MSK [7258] postgres@testdb КОНТЕКСТ:  при изменении кортежа (0,2) в отношении "testt"
2023-11-09 02:31:55.250 MSK [7258] postgres@testdb ОПЕРАТОР:  begin;update testt set x=x+100 where x=(select min(x) from testt ) ; SELECT pg_sleep(5) ; commit ; select now(),'one' ;
2023-11-09 02:31:56.053 MSK [7258] postgres@testdb СООБЩЕНИЕ:  процесс 7258 получил в режиме ShareLock блокировку "транзакция 745" через 1003.433 мс
2023-11-09 02:31:56.053 MSK [7258] postgres@testdb КОНТЕКСТ:  при изменении кортежа (0,2) в отношении "testt"
2023-11-09 02:31:56.053 MSK [7258] postgres@testdb ОПЕРАТОР:  begin;update testt set x=x+100 where x=(select min(x) from testt ) ; SELECT pg_sleep(5) ; commit ; select now(),'one' ;
```

- [x] Смоделируйте ситуацию обновления одной и той же строки тремя командами UPDATE в разных сеансах. 
```sh
sudo -u postgres psql testdb -c "alter table testt add column y varchar(10) default false"
var=`sudo -u postgres psql testdb -c "select ':'||min(x) from testt" |grep :|cut -d : -f 2`;echo $var #12
for i in 1 2 3 ; do sudo -u postgres psql testdb -c "begin ; update testt set y=x+100 where x=$var ; SELECT pg_sleep(10+$var) ; commit ; select now(),$i ;" | cat & done
sudo -u postgres psql testdb -c "select * from pg_locks where not pid = pg_backend_pid() order by pid" | cat
```
```console
[1] 7466
[2] 7468
[3] 7470
```
 | locktype    | database | relation | page | tuple | virtualxid | transactionid |  |  |                       | virtualtransaction | pid  |       mode       | granted | fastpath |           waitstart|
 |--------------|----------|----------|------|-------|------------|---------------|---------|-------|----------|--------------------|------|------------------|---------|---------|-------------------------------|
 |**relation**      |    16384 |    16396 |      |       |            |               |         |       |          | 3/198              | 7477 | RowExclusiveLock | t       | t        ||
 |*virtualxid*    |          |          |      |       | 3/198      |               |         |       |          | 3/198              | 7477 | ExclusiveLock    | t       | t        ||
 |transactionid |          |          |      |       |            |           747 |         |       |          | 3/198              | 7477 | ExclusiveLock    | t       | **f**        ||
 |**relation**      |    16384 |    16396 |      |       |            |               |         |       |          | 4/28               | 7478 | RowExclusiveLock | t       | t        ||
 |*virtualxid*    |          |          |      |       | 4/28       |               |         |       |          | 4/28               | 7478 | ExclusiveLock    | t       | t        ||
 |transactionid |          |          |      |       |            |           747 |         |       |          | 4/28               | 7478 | ShareLock        | **f**       | f        | 2023-11-09 02:43:06.179967+03|
 |transactionid |          |          |      |       |            |           748 |         |       |          | 4/28               | 7478 | ExclusiveLock    | t       | f        ||
 |__tuple__         |    16384 |    16396 |    0 |     3 |            |               |         |       |          | 4/28               | 7478 | ExclusiveLock    | t       | f        ||
 |**relation**      |    16384 |    16396 |      |       |            |               |         |       |          | 5/2                | 7479 | RowExclusiveLock | t       | t        ||
 |*virtualxid*    |          |          |      |       | 5/2        |               |         |       |          | 5/2                | 7479 | ExclusiveLock    | t       | t        ||
 |transactionid |          |          |      |       |            |           749 |         |       |          | 5/2                | 7479 | ExclusiveLock    | t       | f        ||
 |__tuple__         |    16384 |    16396 |    0 |     3 |            |               |         |       |          | 5/2                | 7479 | ExclusiveLock    | **f**       | f        | 2023-11-09 02:43:06.182742+03|
```console
(12 строк)
```

  > Изучите возникшие блокировки в представлении pg_locks и убедитесь, что все они понятны. Пришлите список блокировок и объясните, что значит каждая.

- // https://postgrespro.ru/docs/postgresql/12/view-pg-locks / https://www.postgresql.org/docs/12/explicit-locking.html /  //
- где granted=**t**rue - там блокировка выдана, где granted=**f**alse - блокировка ожидается
- все три пида получили блокировку на virtualxid 
- где pid 7477 - получил блокировку по короткому пути relation:RowExclusiveLock , transactionid(747):ExclusiveLock
- где pid 7478 - ждет waitstart чтобы получить блокировку. Получил relation:RowExclusiveLock и  transactionid(748):ExclusiveLock и на кортеж tuple:ExclusiveLock  . ждет transactionid(747):ExclusiveLock
- где pid 7479 - ждет waitstart чтобы получить блокировку. Получил relation:RowExclusiveLock и  transactionid(749):ExclusiveLock. ждет блокировку tuple (кортеж, экземпляру строки)


|locktype|type|desc|
|-       |-   |-   |
|relation|AccessShareLock|разделяемая блокировка для select|
|virtualxid|ExclusiveLock|Транзакция всегда удерживает исключительную (ExclusiveLock) блокировку собственного номера, а данном случае — виртуального|
|relation|RowExclusiveLock| тут указана relation таблицы `select relname from pg_stat_user_tables where relid=16396;` - исключительная блокировка для изменения строки в таблице testt |
|transactionid|ShareLock|разделяемая блокировка на транзакцию - так как есть не коммитнутое изменение - чтобы его подождать|
|tuple|ExclusiveLock|исключительная блокировка на кортеж|
|transactionid|ExclusiveLock|исключительная блокировка на транзакцию|



- [x] Воспроизведите взаимоблокировку трех транзакций.
```sh
sudo -u postgres psql testdb -c "update testt set y='' "
sudo -u postgres psql testdb -c "begin ; update testt set y=y||'0' where x=$var+0 returning x, y ;SELECT pg_sleep(1) ; update testt set y=y||'1' where x=$var+1 returning x, y ;SELECT pg_sleep(1); commit ;" | cat &
sudo -u postgres psql testdb -c "begin ; update testt set y=y||'0' where x=$var+1 returning x, y ;SELECT pg_sleep(1) ; update testt set y=y||'1' where x=$var+2 returning x, y ;SELECT pg_sleep(1); commit ;" | cat &
sudo -u postgres psql testdb -c "begin ; update testt set y=y||'0' where x=$var+2 returning x, y ;SELECT pg_sleep(1) ; update testt set y=y||'1' where x=$var+0 returning x, y ;SELECT pg_sleep(1); commit ;" | cat &
```

```console
ОШИБКА:  обнаружена взаимоблокировка
ПОДРОБНОСТИ:  Процесс 9185 ожидает в режиме ShareLock блокировку "транзакция 823"; заблокирован процессом 9187.
Процесс 9187 ожидает в режиме ShareLock блокировку "транзакция 822"; заблокирован процессом 9186.
Процесс 9186 ожидает в режиме ShareLock блокировку "транзакция 821"; заблокирован процессом 9185.
ПОДСКАЗКА:  Подробности запроса смотрите в протоколе сервера.
КОНТЕКСТ:  при изменении кортежа (2,5) в отношении "testt"
```

  > ### Можно ли разобраться в ситуации постфактум, изучая журнал сообщений? ###
```log
2023-11-09 04:17:11.289 MSK [9185] postgres@testdb СООБЩЕНИЕ:  процесс 9185 обнаружил взаимоблокировку, ожидая в режиме ShareLock блокировку "транзакция 823" в течение 200.266 мс
2023-11-09 04:17:11.289 MSK [9185] postgres@testdb ПОДРОБНОСТИ:  Process holding the lock: 9187. Wait queue: .
2023-11-09 04:17:11.289 MSK [9185] postgres@testdb КОНТЕКСТ:  при изменении кортежа (2,5) в отношении "testt"
2023-11-09 04:17:11.289 MSK [9185] postgres@testdb ОПЕРАТОР:  begin ; update testt set y=y||'0' where x=21+0 returning x, y ;SELECT pg_sleep(1) ; update testt set y=y||'1' where x=21+1 returning x, y ;SELECT pg_sleep(1); commit ;
2023-11-09 04:17:11.289 MSK [9185] postgres@testdb ОШИБКА:  обнаружена взаимоблокировка
2023-11-09 04:17:11.289 MSK [9185] postgres@testdb ПОДРОБНОСТИ:  Процесс 9185 ожидает в режиме ShareLock блокировку "транзакция 823"; заблокирован процессом 9187.
        Процесс 9187 ожидает в режиме ShareLock блокировку "транзакция 822"; заблокирован процессом 9186.
        Процесс 9186 ожидает в режиме ShareLock блокировку "транзакция 821"; заблокирован процессом 9185.
        Процесс 9185: begin ; update testt set y=y||'0' where x=21+0 returning x, y ;SELECT pg_sleep(1) ; update testt set y=y||'1' where x=21+1 returning x, y ;SELECT pg_sleep(1); commit ;
        Процесс 9187: begin ; update testt set y=y||'0' where x=21+1 returning x, y ;SELECT pg_sleep(1) ; update testt set y=y||'1' where x=21+2 returning x, y ;SELECT pg_sleep(1); commit ;
        Процесс 9186: begin ; update testt set y=y||'0' where x=21+2 returning x, y ;SELECT pg_sleep(1) ; update testt set y=y||'1' where x=21+0 returning x, y ;SELECT pg_sleep(1); commit ;
2023-11-09 04:17:11.289 MSK [9185] postgres@testdb ПОДСКАЗКА:  Подробности запроса смотрите в протоколе сервера.
2023-11-09 04:17:11.289 MSK [9185] postgres@testdb КОНТЕКСТ:  при изменении кортежа (2,5) в отношении "testt"
2023-11-09 04:17:11.289 MSK [9185] postgres@testdb ОПЕРАТОР:  begin ; update testt set y=y||'0' where x=21+0 returning x, y ;SELECT pg_sleep(1) ; update testt set y=y||'1' where x=21+1 returning x, y ;SELECT pg_sleep(1); commit ;
2023-11-09 04:17:11.324 MSK [9187] postgres@testdb СООБЩЕНИЕ:  процесс 9187 продолжает ожидать в режиме ShareLock блокировку "транзакция 822" в течение 200.174 мс
2023-11-09 04:17:11.324 MSK [9187] postgres@testdb ПОДРОБНОСТИ:  Process holding the lock: 9186. Wait queue: 9187.
2023-11-09 04:17:11.324 MSK [9187] postgres@testdb КОНТЕКСТ:  при изменении кортежа (1,2) в отношении "testt"
2023-11-09 04:17:11.324 MSK [9187] postgres@testdb ОПЕРАТОР:  begin ; update testt set y=y||'0' where x=21+1 returning x, y ;SELECT pg_sleep(1) ; update testt set y=y||'1' where x=21+2 returning x, y ;SELECT pg_sleep(1); commit ;
2023-11-09 04:17:12.296 MSK [9187] postgres@testdb СООБЩЕНИЕ:  процесс 9187 получил в режиме ShareLock блокировку "транзакция 822" через 1172.269 мс
2023-11-09 04:17:12.296 MSK [9187] postgres@testdb КОНТЕКСТ:  при изменении кортежа (1,2) в отношении "testt"
2023-11-09 04:17:12.296 MSK [9187] postgres@testdb ОПЕРАТОР:  begin ; update testt set y=y||'0' where x=21+1 returning x, y ;SELECT pg_sleep(1) ; update testt set y=y||'1' where x=21+2 returning x, y ;SELECT pg_sleep(1); commit ;
2023-11-09 04:18:14.522 MSK [6876] СООБЩЕНИЕ:  начата контрольная точка: time
2023-11-09 04:18:15.257 MSK [6876] СООБЩЕНИЕ:  контрольная точка завершена: записано буферов: 8 (0.0%); добавлено файлов WAL 0, удалено: 0, переработано: 0; запись=0.705 сек., синхр.=0.013 сек., всего=0.736 сек.; синхронизировано_файлов=6, самая_долгая_синхр.=0.011 сек., средняя=0.003 сек.; расстояние=35 kB, ожидалось=68 kB
```

#### Да, в журнале и в stderr четко понятна причина - что произошло и как к этому пришли. ####

- [x] Могут ли две транзакции, выполняющие единственную команду UPDATE одной и той же таблицы (без where), заблокировать друг друга?
Похоже врядли это получится ... т.к. какой то из них лочить будет таблицу эсклюзивно первым

- [x] ✵ Попробуйте воспроизвести такую ситуацию.
```sh
sudo -u postgres psql testdb -c "update test1 set y=(16396)::varchar||pg_sleep(2)||(select sum(x) from test1);" & sudo -u postgres psql testdb -c "update test1 set y=(16396)::varchar||pg_sleep(1)||(select sum(x) from tes10);" &
# не вышло никак
```

```console
sudo -u postgres psql testdb -c "update test1 set x=x+1,y=(16396)::varchar||pg_sleep(1)||x;" & sudo -u postgres psql testdb -c "update test1 set x=x-1,y=(16396)::varchar||pg_sleep(1)||x;" & sudo -u postgres psql testdb -c "select pg_sleep(1), l.* from pg_locks l where pid!=pg_backend_pid() order by pid " | cat &  sleep 1s ; echo -e '\n\n\n'

# и так не вышло
UPDATE 1
UPDATE 1
 pg_sleep |  locktype  | database | relation | page | tuple | virtualxid | transactionid | classid | objid | objsubid | virtualtransaction |  pid  |       mode       | granted | fastpath | waitstart
----------+------------+----------+----------+------+-------+------------+---------------+---------+-------+----------+--------------------+-------+------------------+---------+----------+-----------
          | relation   |    16384 |    16400 |      |       |            |               |         |       |          | 3/1130             | 10510 | RowExclusiveLock | t       | t        |
          | virtualxid |          |          |      |       | 3/1130     |               |         |       |          | 3/1130             | 10510 | ExclusiveLock    | t       | t        |
          | relation   |    16384 |    16400 |      |       |            |               |         |       |          | 4/410              | 10511 | RowExclusiveLock | t       | t        |
          | virtualxid |          |          |      |       | 4/410      |               |         |       |          | 4/410              | 10511 | ExclusiveLock    | t       | t        |

```

```sh
sudo -u postgres psql testdb -c "create table tes10 as select x,'' y from generate_series(1,10)x;"
sudo -u postgres psql testdb -c "update tes10 set y=pg_advisory_lock(16396)::varchar||pg_sleep(2)||(select sum(x) from test1);" & sudo -u postgres psql testdb -c "update tes10 set y=pg_advisory_lock(16396)::varchar||pg_sleep(1)||(select sum(x) from tes10);" &

```
Одна транзакция ждала другую...
```console
2023-11-09 05:06:28.399 MSK [10145] postgres@testdb СООБЩЕНИЕ:  процесс 10145 продолжает ожидать в режиме ExclusiveLock блокировку "рекомендательная блокировка [16384,0,16396,1]" в течение 200.212 мс
2023-11-09 05:06:28.399 MSK [10145] postgres@testdb ПОДРОБНОСТИ:  Process holding the lock: 10144. Wait queue: 10145.
2023-11-09 05:06:28.399 MSK [10145] postgres@testdb ОПЕРАТОР:  update tes10 set y=pg_advisory_lock(16396)::varchar||pg_sleep(1)||(select sum(x) from tes10);
2023-11-09 05:06:30.221 MSK [10145] postgres@testdb СООБЩЕНИЕ:  процесс 10145 получил в режиме ExclusiveLock блокировку "рекомендательная блокировка [16384,0,16396,1]" через 2022.290 мс
2023-11-09 05:06:30.221 MSK [10145] postgres@testdb ОПЕРАТОР:  update tes10 set y=pg_advisory_lock(16396)::varchar||pg_sleep(1)||(select sum(x) from tes10)
```


