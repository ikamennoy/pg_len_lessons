# Домашнее задание *Нагрузочное тестирование и тюнинг PostgreSQL* #
- сделать нагрузочное тестирование PostgreSQL
- настроить параметры PostgreSQL для достижения максимальной производительности

# Описание/Пошаговая инструкция выполнения домашнего задания: #
- [x] развернуть виртуальную машину любым удобным способом
```sh
yc vpc network create --name testnetb; yc vpc subnet create --network-name testnetb --name subnetb --zone 'ru-central1-b' --range '10.0.130.0/24'
yc compute instance create --name tu22p --metadata-from-file user-data=meta.yaml --create-boot-disk name=root-disk2,type=network-ssd,size=10G,auto-delete,image-folder-id=standard-images,image-family=ubuntu-2204-lts --memory 4G --cores 2 --hostname upgtest --metadata serial-port-enable=1 --zone ru-central1-b --core-fraction 50 --preemptible --platform standard-v2; yc compute instance add-one-to-one-nat tu22p --network-interface-index 0 ; yc compute connect-to-serial-port --instance-name tu22p --ssh-key .ssh/yc_serialssh_key --user uuu
```

- [x] поставить на неё _PostgreSQL 15_ любым способом
## уже включено через [meta.yaml](home_11/meta.yaml) + [once.sh](home_11/once.sh) через crontab ##


- [x] настроить кластер _PostgreSQL 15_ на максимальную производительность не обращая внимание на возможные проблемы с надежностью в случае аварийной перезагрузки виртуальной машины
```sh
sudo -u postgres -i
psql -c "alter system set synchronous_commit = off"
psql -c "alter system set wal_writer_delay = 1000"
psql -c "alter system set checkpoint_timeout = 900"
psql -c "SELECT pg_reload_conf()"
psql -c "SELECT * from pg_file_settings where not applied;" |cat # нету
psql -c "SELECT * from pg_settings where pending_restart;" |cat # нету
```

- [x] нагрузить кластер через утилиту через утилиту [pgbench](https://postgrespro.ru/docs/postgrespro/15/pgbench)
```
pgbench -i postgres
pgbench -c20 -T 600 -U postgres postgres
```
```console
pgbench (15.5 (Ubuntu 15.5-1.pgdg22.04+1))
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 20
number of threads: 1
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 1406881
number of failed transactions: 0 (0.000%)
latency average = 8.529 ms
initial connection time = 72.903 ms
tps = 2344.903955 (without initial connection time)
```

- [x] написать какого значения tps удалось достичь, показать какие параметры в какие значения устанавливали и почему
  - Добился 2344 tps

  - какие:
```console
psql -c "SELECT name,setting,context from pg_settings where name in ('checkpoint_timeout','wal_writer_delay','synchronous_commit') "|cat
        name        | setting | context
--------------------+---------+---------
 checkpoint_timeout | 900     | sighup
 synchronous_commit | off     | user
 wal_writer_delay   | 1000    | sighup
(3 строки)
```
-
  - Почему:

|параметр|описание|
|-|-|
|[checkpoint_timeout](https://postgresqlco.nf/doc/en/param/checkpoint_timeout/)| - задает как сохраняем чекпоинты - за счет потери времени в случае аварийного старта|
|[synchronous_commit](https://postgresqlco.nf/doc/en/param/synchronous_commit/)-|, будет ли сервер при фиксировании транзакции ждать, пока записи из WAL сохранятся на диске, прежде чем сообщить клиенту об успешном завершении операции. Со значением off может образоваться окно от момента, когда клиент узнаёт об успешном завершении, до момента, когда транзакция действительно гарантированно защищена от сбоя. (Максимальный размер окна равен тройному значению *wal_writer_delay* .)|
|[wal_writer_delay](https://postgresqlco.nf/doc/en/param/wal_writer_delay/)|  - зададим как быстро сбрасывает на диск

### Из прошлых тестов получил, что самые эффективные параметры для улучшения tps в тестах pgbench - если не страшны возможные проблемы с надежностью в случае аварийной перезагрузки ###
  full_page_writes, fsync and synchronous_commit - если бы было бы важно, то лучше включить эти параметры - чтобы нивелировать риски, но в тоже время это самая тяжелая часть
------

- [x] ✵ протестировать через [sysbench-tpcc](https://github.com/Percona-Lab/sysbench-tpcc) // требует установки [sysbench](https://github.com/akopytov/sysbench) 
```sh
yc compute instance delete --name tu22p

yc compute instance create --name tu22p --metadata-from-file user-data=meta.yaml --create-boot-disk name=root-disk2,type=network-ssd,size=200G,auto-delete,image-folder-id=standard-images,image-family=ubuntu-2204-lts --memory 16G --cores 4 --hostname upgtest --metadata serial-port-enable=1 --zone ru-central1-b --core-fraction 50 --preemptible --platform standard-v2; yc compute instance add-one-to-one-nat tu22p --network-interface-index 0 ; yc compute connect-to-serial-port --instance-name tu22p --ssh-key .ssh/yc_serialssh_key --user uuu

curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.deb.sh | sudo bash
sudo apt -y install sysbench

sudo -i -u postgres
psql -c "alter system set synchronous_commit = off"
psql -c "alter system set wal_writer_delay = 1000"
psql -c "alter system set checkpoint_timeout = 900"
psql -c "alter system set shared_buffers = 1024"
psql -c "alter user postgres  password 'test123' "
exit
sudo pg_ctlcluster restart 15 main

sudo -i -u postgres
git clone https://github.com/Percona-Lab/sysbench-tpcc
cd sysbench-tpcc
./tpcc.lua prepare --db-driver=pgsql --pgsql-db=postgres --pgsql-user=postgres  --pgsql-password="test123" --scale=3
```
```console
DB SCHEMA public
Creating tables: 1

Adding indexes 1 ...

Adding FK 1 ...

Waiting on tables 30 sec

loading tables: 1 for warehouse: 1
...

```

```sh
./tpcc.lua run --db-driver=pgsql --pgsql-db=postgres --pgsql-user=postgres  --pgsql-password="test123" --scale=3
```
```console
sysbench 1.0.20 (using system LuaJIT 2.1.0-beta3)

Running the test with following options:
Number of threads: 1
Initializing random number generator from current time


Initializing worker threads...

DB SCHEMA public
Threads started!

SQL statistics:
    queries performed:
        read:                            17590
        write:                           18179
        other:                           2700
        total:                           38469
    transactions:                        1349   (134.86 per sec.)
    queries:                             38469  (3845.71 per sec.)
    ignored errors:                      6      (0.60 per sec.)
    reconnects:                          0      (0.00 per sec.)

General statistics:
    total time:                          10.0014s
    total number of events:              1349

Latency (ms):
         min:                                    0.55
         avg:                                    7.41
         max:                                  547.88
         95th percentile:                       21.50
         sum:                                 9995.01

Threads fairness:
    events (avg/stddev):           1349.0000/0.00
    execution time (avg/stddev):   9.9950/0.00
```

## [end](home_11/end.sh) ##
