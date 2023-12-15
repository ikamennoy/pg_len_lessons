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
select b.book_ref
,b.total_amount
,sum(tf.amount) as check_sum
,count(case when tf.fare_conditions=s.fare_conditions then null else 1 end) as fail_conditions
,round(100.0*count(p.ticket_no)/count(tf.ticket_no),2) as Person_at_board
from bookings.bookings b
 join bookings.tickets t on b.book_ref =t.book_ref 
 join bookings.ticket_flights tf on tf.ticket_no = t.ticket_no 
left join bookings.boarding_passes p on p.ticket_no =t.ticket_no --and p.flight_id =tf.flight_id  
left join bookings.flights f on f.flight_id=tf.flight_id
left join bookings.seats s on s.seat_no = p.seat_no and f.aircraft_code=s.aircraft_code
left join bookings.aircrafts c on c.aircraft_code=f.aircraft_code
left join bookings.airports d on f.departure_airport = d.airport_code 
left join bookings.airports a on f.arrival_airport = a.airport_code 
group by b.book_ref
```
- Проверка итоговой суммы и суммы по билетам (  total_amount = sum(tf.amount) )
- Проверка соответствия условий места в билете и самолете
- % севших в самолет
