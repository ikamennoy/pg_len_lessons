|Домашнее задание| Триггеры, поддержка заполнения витрин|
|-|-|
|Цель|Создать триггер для поддержки витрины в актуальном состоянии.|

|Описание/Пошаговая инструкция выполнения домашнего задания:|
|-|
|Скрипт и развернутое описание задачи – в ЛК (файл hw_triggers.sql) или по ссылке: https://disk.yandex.ru/d/l70AvknAepIJXQ
В БД создана структура, описывающая товары (таблица goods) и продажи (таблица sales).
Есть запрос для генерации отчета – сумма продаж по каждому товару.
БД была денормализована, создана таблица (витрина), структура которой повторяет структуру отчета.
Создать триггер на таблице продаж, для поддержки данных в витрине в актуальном состоянии (вычисляющий при каждой продаже сумму и записывающий её в витрину)|
|Подсказка: не забыть, что кроме INSERT есть еще UPDATE и DELETE|
|Задание со звездочкой* Чем такая схема (витрина+триггер) предпочтительнее отчета, создаваемого "по требованию" (кроме производительности)? Подсказка: В реальной жизни возможны изменения цен.|

## Решение ##
```sh
# инициализация схемы - запускаем файл hw_triggers.sql
curl https://raw.githubusercontent.com/ikamennoy/pg_len_lessons/main/home_23/hw_triggers.sql | psql -f -
```
```sql
insert into good_sum_mart -- заполняем данными
SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name
returning * ;
```
|good_name|sum_sale|
|---------|--------|
|Автомобиль Ferrari FXX K|185000000.01|
|Спички хозайственные|65.50|

```sql
CREATE OR REPLACE FUNCTION trig_func_hw_sales() -- создаем триггерную функцию
RETURNS trigger
AS
$$
DECLARE
    sale_row record;
    sale_str text;
    sale_exists int8;
    report_row record;
BEGIN
    IF TG_LEVEL = 'ROW' THEN
        CASE 
            WHEN TG_OP = 'DELETE'
                THEN sale_row = OLD;
                sale_str = OLD::text;
                update good_sum_mart set sum_sale = sum_sale - OLD.sales_qty * goods.good_price from goods where goods.good_name = good_sum_mart.good_name and goods.goods_id = OLD.good_id;
            WHEN TG_OP in ('UPDATE', 'INSERT')
                then case 
                     when TG_OP = 'UPDATE' 
                         THEN sale_row = NEW; sale_str = 'UPDATE FROM ' || OLD || ' TO ' || NEW;
                         update good_sum_mart set sum_sale = sum_sale - OLD.sales_qty * goods.good_price from goods where goods.good_name = good_sum_mart.good_name and goods.goods_id = OLD.good_id;
                     when TG_OP = 'INSERT' THEN sale_row = NEW; 
                         sale_str = NEW::text; 
                     END CASE;
                select count(*) strict into sale_exists from good_sum_mart join goods on goods.good_name = good_sum_mart.good_name and goods.goods_id = NEW.good_id ;
               RAISE notice E'% rows in good_sum_mart', sale_exists;
                if sale_exists = 0 then
                   insert into good_sum_mart 
                   SELECT goods.good_name,
                     (goods.good_price * NEW.sales_qty) 
                      FROM goods
                      where goods.goods_id = NEW.good_id ;
                 elsif sale_exists = 1 then 
                    update good_sum_mart set sum_sale = sum_sale + NEW.sales_qty * goods.good_price from goods where goods.good_name = good_sum_mart.good_name and goods.goods_id = NEW.good_id;
                 else RAISE EXCEPTION  E'the table "good_sum_mart" contain % rows with same good_name \n TABLE_NAME = %\n TG_WHEN = %\n TG_OP = %\n TG_LEVEL = %\n sale_str: %\n -------------', sale_exists, TG_TABLE_NAME, TG_WHEN, TG_OP, TG_LEVEL, sale_str;
                 end if;
        END CASE;

    else 
    RAISE EXCEPTION  E'INVALID TG_LEVEL \n TABLE_NAME = %\n TG_WHEN = %\n TG_OP = %\n TG_LEVEL = %\n sale_str: %\n -------------', TG_TABLE_NAME, TG_WHEN, TG_OP, TG_LEVEL, sale_str;
    END IF;
    
    RAISE notice E'TRACE \n TABLE_NAME = %\n TG_WHEN = %\n TG_OP = %\n TG_LEVEL = %\n sale_str: %\n -------------', TG_TABLE_NAME, TG_WHEN, TG_OP, TG_LEVEL, sale_str;
    RETURN sale_row;
END;
$$
LANGUAGE plpgsql 
SECURITY DEFINER;
```

```sql
CREATE TRIGGER trigger_hw_sales -- вешаем триггер на sales как задано в задаче
BEFORE INSERT OR UPDATE or delete
ON sales
FOR EACH ROW
EXECUTE PROCEDURE trig_func_hw_sales();
```

```sql
insert into goods values (3, 'Спички охотничьи', 1.70); -- заводим новый товар
```
```sql
insert into sales (good_id, sales_qty) values (3,10);
-- в good_sum_mart строка Спички охотничьи	17.00
```
```sql
delete from sales where good_id=3;
-- в good_sum_mart обновилась строка Спички охотничьи	0.00
```
```sql
insert into sales (good_id, sales_qty) values (3,11) returning *;
-- 5	3	2024-01-10 00:32:17.991 +0300	11
-- в good_sum_mart Спички охотничьи	18.70
update sales set sales_qty=10 where sales_id=5;
-- в good_sum_mart Спички охотничьи	17.00
```

Указанная схема дает помимо потрясающего быстродействия (при огромном числе продаж) также фиксацию итоговой суммы с учетом цены товара в прошлом.
Другими словами после обновления цены в goods для новых продаж ( и других изменений) будет добавлятся сумма по новой цене, но в тоже время старые сделки будут зафиксированы с исторической ценой.
Позволяет не фиксировать изменение цены - еще одну таблицу где будет goods_id и период (или дата фиксации цены) - простая и функциональная схема. Также позволяет оценить насколько результат 
```sql
SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name
```
отличается от good_sum_mart - т.е. подбирать нужный баланс цен при внедрении каких то акций или маркетинговых кампаний. Или посмотреть объем выручки исторический или по текущей цене.
Также полезно если цена может меняться очень часто - очень сильно упрощает учет сделок - когда хранить динамику изменения цены товара не нужно.
