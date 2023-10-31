# Домашнее задание - *Работа с журналами* #
## Цель: ##
- уметь работать с журналами и контрольными точками
- уметь настраивать параметры журналов


## Описание/Пошаговая инструкция выполнения домашнего задания: ##

- [x] Настройте выполнение контрольной точки раз в 30 секунд.
```sql
alter system set checkpoint_timeout = 1800;
```

- [x] 10 минут c помощью утилиты pgbench подавайте нагрузку.
```
psql -c "create database testdb"
pgbench -i testdb
time pgbench -c20 -P 6 -T 600 -U postgres testdb
```

- [ ] Измерьте, какой объем журнальных файлов был сгенерирован за это время. Оцените, какой объем приходится в среднем на одну контрольную точку.

- [ ] Проверьте данные статистики: все ли контрольные точки выполнялись точно по расписанию. Почему так произошло?

- [ ] Сравните tps в синхронном/асинхронном режиме утилитой pgbench. Объясните полученный результат.

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

  -  [+] Создайте таблицу.
```sh
psql -c "create table t2(nn int4)"
```

  -  [+] Вставьте несколько значений.
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

