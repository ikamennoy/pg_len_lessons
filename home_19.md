# Домашнее задание : Работа с join'ами, статистикой #
#### Цель
- знать и уметь применять различные виды join'ов
- строить и анализировать план выполнения запроса
- оптимизировать запрос
- уметь собирать и анализировать статистику для таблицы
### Описание/Пошаговая инструкция выполнения домашнего задания: ###
В результате выполнения ДЗ вы научитесь пользоваться различными вариантами соединения таблиц.
В данном задании тренируются навыки: написания запросов с различными типами соединений
- Необходимо:
- [x] Реализовать прямое соединение двух или более таблиц
```sql
select flight_no, min(scheduled_departure) as scheduled_departure,count(*) as cnt,avg(f.scheduled_arrival -scheduled_departure) as delta , f.departure_airport,arrival_airport,status,t.amount 
from flights f
 join bookings.ticket_flights t on t.flight_id = f.flight_id 
where t.fare_conditions ='Business' and f.flight_no ='PG0547' and status='Scheduled' and f.scheduled_departure >current_date-interval '8' year
group by flight_no, f.departure_airport,arrival_airport,status,t.amount  
```
|flight_no|scheduled_departure|cnt|delta|departure_airport|arrival_airport|status|amount|
|---------|-------------------|---|-----|-----------------|---------------|------|------|
|PG0547|2016-10-15 09:25:00.000 +0300|304|04:25:00|SVO|KJA|Scheduled|99800.00|


- [x] Реализовать левостороннее (или правостороннее) соединение двух или более таблиц
```sql
select flight_no, min(scheduled_departure) as scheduled_departure,count(*) as cnt,avg(f.scheduled_arrival -scheduled_departure) as delta , f.departure_airport,arrival_airport,status,t.amount 
from flights f
left join bookings.ticket_flights t on t.flight_id = f.flight_id 
     and t.fare_conditions ='Business'
where   f.flight_no ='PG0547' and status='Scheduled' and f.scheduled_departure >current_date-interval '8' year
group by flight_no, f.departure_airport,arrival_airport,status,t.amount
```
|flight_no|scheduled_departure|cnt|delta|departure_airport|arrival_airport|status|amount|
|---------|-------------------|---|-----|-----------------|---------------|------|------|
|PG0547|2016-10-15 09:25:00.000 +0300|304|04:25:00|SVO|KJA|Scheduled|99800.00|
|PG0547|2016-11-11 09:25:00.000 +0300|2|04:25:00|SVO|KJA|Scheduled||


- [x] Реализовать кросс соединение двух или более таблиц
```sql
select *
from bookings.seats f
cross join pg_catalog.generate_series(1,2)x
where seat_no='2A' and aircraft_code='319'
```
|aircraft_code|seat_no|fare_conditions|x|
|-------------|-------|---------------|-|
|319|2A|Business|1|
|319|2A|Business|2|


- [x] Реализовать полное соединение двух или более таблиц
```sql
select *
from bookings.boarding_passes b
full outer join bookings.ticket_flights t on t.ticket_no = b.ticket_no and t.flight_id=b.flight_id 
where ((b.ticket_no =t.ticket_no and  fare_conditions ='Business') or t.ticket_no ='0005435007506')
and amount<=8000
```

|ticket_no|flight_id|boarding_no|seat_no|ticket_no|flight_id|fare_conditions|amount|
|---------|---------|-----------|-------|---------|---------|---------------|------|
|-|-|-|-|0005435007506|32218|Economy|6000.00|



- [x] Реализовать запрос, в котором будут использованы разные типы соединений


- [x] Сделать комментарии на каждый запрос

- [x] К работе приложить структуру таблиц, для которых выполнялись соединения
![/home_11/demo_booking.png](/home_11/demo_booking.png)

- [x] Придумайте 3 своих метрики на основе показанных представлений, отправьте их через ЛК, а так же поделитесь с коллегами в слаке
```
--    
select 
f.flight_id, --рейс
--string_agg(distinct f.status,',') as status ,
sum(z.amount) as amount, --стоимость проданных билетов рейса
count(f.flight_id) as bye  -- купили
,count(case when (select count(*) from bookings.boarding_passes p where p.flight_id=f.flight_id and p.ticket_no=z.ticket_no)>0 then 1 end) as board -- сели
,avg(f.actual_arrival-f.scheduled_arrival) as latency  -- задержка
from bookings.flights f 
 join bookings.aircrafts c on c.aircraft_code=f.aircraft_code
 join bookings.airports d on f.departure_airport = d.airport_code 
 join bookings.airports a on f.arrival_airport = a.airport_code 
 join  bookings.ticket_flights z on z.flight_id  = f.flight_id
 where scheduled_arrival between '2016-10-13 01:00:00.000 +0300' and '2016-10-13 17:00:00.000 +0300'
and a.city='Санкт-Петербург' and f.flight_id>=188074
group by f.flight_id
order by f.flight_id desc fetch first 10 rows only
```
```
|QUERY PLAN|
|----------|
|Limit  (cost=0.98..18266.86 rows=10 width=100)|
|  ->  GroupAggregate  (cost=0.98..71237.90 rows=39 width=100)|
|        Group Key: f.flight_id|
|        ->  Nested Loop  (cost=0.98..71057.43 rows=39 width=48)|
|              ->  Nested Loop  (cost=0.42..1231.65 rows=1 width=28)|
|                    Join Filter: (f.departure_airport = d.airport_code)|
|                    ->  Nested Loop  (cost=0.42..1227.31 rows=1 width=32)|
|                          Join Filter: (f.aircraft_code = c.aircraft_code)|
|                          ->  Nested Loop  (cost=0.42..1226.11 rows=1 width=36)|
|                                Join Filter: (f.arrival_airport = a.airport_code)|
|                                ->  Index Scan Backward using flights_pkey on flights f  (cost=0.42..1222.13 rows=45 width=40)|
|                                      Index Cond: (flight_id >= 188074)|
|                                      Filter: ((scheduled_arrival >= '2016-10-13 01:00:00+03'::timestamp with time zone) AND (scheduled_arrival <= '2016-10-13 17:00:00+03'::timestamp with time zone))|
|                                ->  Materialize  (cost=0.00..3.30 rows=1 width=4)|
|                                      ->  Seq Scan on airports a  (cost=0.00..3.30 rows=1 width=4)|
|                                            Filter: (city = 'Санкт-Петербург'::text)|
|                          ->  Seq Scan on aircrafts c  (cost=0.00..1.09 rows=9 width=16)|
|                    ->  Seq Scan on airports d  (cost=0.00..3.04 rows=104 width=4)|
|              ->  Index Scan using ticket_flights_pkey on ticket_flights z  (cost=0.56..69824.74 rows=103 width=24)|
|                    Index Cond: (flight_id = f.flight_id)|
|        SubPlan 1|
|          ->  Aggregate  (cost=4.58..4.59 rows=1 width=8)|
|                ->  Index Only Scan using boarding_passes_pkey on boarding_passes p  (cost=0.56..4.58 rows=1 width=0)|
|                      Index Cond: ((ticket_no = z.ticket_no) AND (flight_id = f.flight_id))|
```
- Задержка прибытия
- сколько село
- сколько билетов
- стоимость проданных билетов рейса
