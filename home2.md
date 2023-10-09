# ДЗ: Работа с уровнями изоляции транзакции в PostgreSQL #

> ## Цель: ##
> * научиться работать с Google [Cloud](https://cloud.yandex.ru/docs/managed-kubernetes/operations/node-connect-ssh) Platform на уровне Google Compute Engine (IaaS)
> * [научиться управлять уровнем изолции транзации в PostgreSQL и понимать особенность работы уровней read commited и repeatable read](https://postgrespro.ru/docs/postgresql/14/sql-set-transaction)


> ## Описание/Пошаговая инструкция выполнения домашнего задания: ##
> * создать новый проект в Google Cloud Platform, Яндекс облако или на любых ВМ, докере
> * далее создать инстанс виртуальной машины с дефолтными параметрами
> * бавить свой ssh ключ в metadata ВМ
> * зайти удаленным ssh (первая сессия), не забывайте про ssh-add
> * поставить PostgreSQL
> * зайти вторым ssh (вторая сессия)
> * запустить везде psql из под пользователя postgres
> * выключить auto commit
```sql
\set AUTOCOMMIT off
```
> *  сделать
> *  * в первой сессии новую таблицу и наполнить ее данными 
```sql
create database test;
/c test;
create table persons(id serial, first_name text, second_name text);
insert into persons(first_name, second_name) values('ivan', 'ivanov'), ('petr', 'petrov'); 
commit;
```
```
INSERT 0 2
```
> * * посмотреть текущий уровень изоляции:
```sql
show transaction isolation level
```
```
test-*# ;
 transaction_isolation
-----------------------
 read committed
(1 row)
```

> * * начать новую транзакцию в обоих сессиях с дефолтным (не меняя) уровнем изоляции
```sql
begin;
insert into persons(first_name, second_name) values('sergey', 'sergeev'); --в первой сессии добавить новую запись insert into persons(first_name, second_name) values('sergey', 'sergeev');
```

```sql
select * from persons where first_name = 'sergey' -- сделать select * from persons во второй сессии
```
```
test-*# ;
 id | first_name | second_name
----+------------+-------------
(0 rows)
```

> *  **видите ли вы новую запись и если да то почему?**
## Не вижу - потому что изменения не коммитнуты в 1 сессии. ##

---------------


> * завершить первую транзакцию - commit;
```sql
commit
```

> * сделать select * from persons во второй сессии
> **видите ли вы новую запись и если да то почему?**
```
test=*# select * from persons where first_name = 'sergey';
 id | first_name | second_name
----+------------+-------------
  5 | sergey     | sergeev
(1 row)
```
## Да, вижу - потому что коммитнул изменения. ##

> * завершите транзакцию во второй сессии
```sql
commit;
```
---------------
> * начать новые но уже repeatable read транзации -
> * * в первой сессии добавить новую запись insert into persons(first_name, second_name) values('sveta', 'svetova');
```sql
test=# BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN
test=*# select * from persons;
 id | first_name | second_name
----+------------+-------------
  3 | ivan       | ivanov
  4 | petr       | petrov
  5 | sergey     | sergeev
(3 rows)

test=*# insert into persons(first_name, second_name) values('sveta', 'svetova');
INSERT 0 1
test=*# commit;
COMMIT
test=# select * from persons;
 id | first_name | second_name
----+------------+-------------
  3 | ivan       | ivanov
  4 | petr       | petrov
  5 | sergey     | sergeev
 10 | sveta      | svetova
(4 rows)
```

> * * сделать select * from persons во второй сессии
```sql
test=# BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN
test=*# select * from persons;
 id | first_name | second_name
----+------------+-------------
  3 | ivan       | ivanov
  4 | petr       | petrov
  5 | sergey     | sergeev
(3 rows)
```
> * * **видите ли вы новую запись и если да то почему?**
нет, потому что не коммитнута транзакция и режим изоляции
> * завершить первую транзакцию - commit;
> * * сделать select * from persons во второй сессии
```sql
test=*# select * from persons;
 id | first_name | second_name
----+------------+-------------
  3 | ivan       | ivanov
  4 | petr       | petrov
  5 | sergey     | sergeev
(3 rows)

test=*#
```
> * **видите ли вы новую запись и если да то почему?**
## не вижу - потому что в этом режиме изоляции я вижу снимок на начало транзакции ##

> * * завершить вторую транзакцию
> * * сделать select * from persons во второй сессии
> * * **видите ли вы новую запись и если да то почему?**
```sql
test=*# commit ;
COMMIT
test=# select * from persons;
 id | first_name | second_name
----+------------+-------------
  3 | ivan       | ivanov
  4 | petr       | petrov
  5 | sergey     | sergeev
 10 | sveta      | svetova
(4 rows)

test=*#
```
## вижу потому что новая транзакция - старый снимок более не доступен ##


