# ДЗ: Работа с уровнями изоляции транзакции в PostgreSQL

```
### Цель:
### научиться работать с Google Cloud Platform на уровне Google Compute Engine (IaaS)
### научиться управлять уровнем изолции транзации в PostgreSQL и понимать особенность работы уровней read commited и repeatable read


#### Описание/Пошаговая инструкция выполнения домашнего задания:
[+] создать новый проект в Google Cloud Platform, Яндекс облако или на любых ВМ, докере
    далее создать инстанс виртуальной машины с дефолтными параметрами
    добавить свой ssh ключ в metadata ВМ
    зайти удаленным ssh (первая сессия), не забывайте про ssh-add
    поставить PostgreSQL
[+] зайти вторым ssh (вторая сессия)
[+] запустить везде psql из под пользователя postgres
[+] выключить auto commit
[+] сделать

в первой сессии новую таблицу и наполнить ее данными 

```
create table persons(id serial, first_name text, second_name text);
insert into persons(first_name, second_name) values('ivan', 'ivanov'), ('petr', 'petrov'); 
commit;
```

```
INSERT 0 2
```

посмотреть текущий уровень изоляции: `show transaction isolation level`
```
test-*# ;
 transaction_isolation
-----------------------
 read committed
(1 row)
```

[+] начать новую транзакцию в обоих сессиях с дефолтным (не меняя) уровнем изоляции


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

* видите ли вы новую запись и если да то почему?
Не вижу - потому что изменения не коммитнуты в 1 сессии.




завершить первую транзакцию - commit;
сделать select * from persons во второй сессии
видите ли вы новую запись и если да то почему?
завершите транзакцию во второй сессии
начать новые но уже repeatable read транзации - set transaction isolation level repeatable read;
в первой сессии добавить новую запись insert into persons(first_name, second_name) values('sveta', 'svetova');
сделать select * from persons во второй сессии
видите ли вы новую запись и если да то почему?
завершить первую транзакцию - commit;
сделать select * from persons во второй сессии
видите ли вы новую запись и если да то почему?
завершить вторую транзакцию
сделать select * from persons во второй сессии
видите ли вы новую запись и если да то почему? ДЗ сдаем в виде миниотчета в markdown в гите
