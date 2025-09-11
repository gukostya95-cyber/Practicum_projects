/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Гуреев Константин Викторович
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT COUNT(id) AS total_users, 		
SUM(payer) AS total_users_pay,
 		ROUND(AVG(payer)::numeric,2) AS share_users
FROM fantasy.users;
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT DISTINCT race,
		COUNT(id) OVER (PARTITION BY race_id) AS total_users,
		SUM(payer) OVER (PARTITION BY race_id) AS total_users_pay,
		ROUND(AVG(payer) OVER (PARTITION BY race_id)::NUMERIC,2) AS share_user_race
FROM fantasy.users AS u 
LEFT JOIN fantasy.race AS r USING(race_id)
ORDER BY total_users DESC; 
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(transaction_id) AS total_transactions,
		SUM(amount) AS sum_amount,
		MAX(amount) AS max_amount,
		MIN(amount) AS min_amount,
		AVG(amount) AS avg_amount,
		PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY amount) AS mediana_amount,
		STDDEV(amount) AS std_amount
FROM fantasy.events;
-- 2.2: Аномальные нулевые покупки:
SELECT  COUNT(transaction_id) FILTER(WHERE amount=0)  AS zero_count_amount,
        COUNT(transaction_id) AS total_amount,
		COUNT(transaction_id) FILTER (WHERE amount=0)/COUNT(transaction_id)::float AS share_amount_zero
FROM fantasy.events;
-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
WITH pay_no_pay_users AS
(SELECT  'неплатящие' AS category,   u.id,
		COUNT(transaction_id) OVER (PARTITION BY u.id) AS total_no_pay,
		SUM(amount) OVER (PARTITION BY u.id) AS sum_user_no_pay
FROM fantasy.events AS e 
RIGHT JOIN fantasy.users AS u USING(id)
WHERE amount<>0 AND payer=0
UNION  
SELECT 'платящие',  u.id,
		COUNT(transaction_id) OVER (PARTITION BY u.id) AS total_pay,
		SUM(amount) OVER (PARTITION BY u.id) AS sum_user_pay
FROM fantasy.events AS e 
RIGHT JOIN fantasy.users AS u USING(id)
WHERE  amount<>0 AND payer=1)
SELECT category,
		COUNT(id) AS total_users,
		ROUND(AVG(total_no_pay)::numeric,2) AS avg_count_pay,
		ROUND(AVG(sum_user_no_pay)::numeric,2) AS avg_sum_amount
FROM pay_no_pay_users
GROUP BY category; 
-- 2.4: Популярные эпические предметы:
SELECT game_items,
		COUNT (e.transaction_id) AS total_pay_items,
		COUNT (DISTINCT e.id) AS unique_users,
		ROUND(COUNT(e.transaction_id)/(SELECT COUNT(transaction_id) FILTER (WHERE amount<>0) FROM fantasy.events)::NUMERIC,2) AS share_items,
		ROUND(COUNT (DISTINCT e.id)/ (SELECT COUNT(DISTINCT id) FILTER (WHERE amount<>0) FROM fantasy.events)::NUMERIC,2) AS share_users
FROM fantasy.events AS e
RIGHT JOIN fantasy.items AS i USING(item_code)
WHERE amount<>0
GROUP BY game_items
ORDER BY total_pay_items DESC;
-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь
WITH    total_users_race AS (
		SELECT race_id,
				COUNT(*) AS total_users
		FROM fantasy.users
		GROUP BY race_id),
		total_pay_users_race AS (
		SELECT u.race_id,
				COUNT(DISTINCT e.id) AS total_pay_users,
				ROUND(COUNT( DISTINCT e.id) FILTER (WHERE payer=1) /COUNT(DISTINCT e.id)::NUMERIC,2) AS share_users_pay
		FROM fantasy.users AS u 
		JOIN fantasy.events AS e ON u.id=e.id
		WHERE amount<>0
		GROUP BY u.race_id),
		activiti_users_race AS (
		SELECT  id,
				COUNT(*) AS count_pay_user,
				AVG(amount) AS avg_amount,
				SUM(amount) AS sum_amount
		FROM fantasy.events
		WHERE amount<>0
		GROUP BY id)
SELECT DISTINCT r.race, total_users, total_pay_users, share_users_pay,
		ROUND(total_pay_users/ total_users::NUMERIC,2) AS share_pay_users_total_users,
		ROUND(AVG(count_pay_user) OVER(PARTITION BY e.race_id)::NUMERIC,2) AS avg_count_race,
		ROUND(AVG(avg_amount) OVER (PARTITION BY e.race_id)::NUMERIC,2) AS avg_amount_race,
		ROUND(AVG(sum_amount) OVER (PARTITION BY e.race_id)::numeric/AVG(count_pay_user) OVER(PARTITION BY e.race_id)::NUMERIC,2) AS avg_standart,
		ROUND(AVG(sum_amount) OVER (PARTITION BY e.race_id)::NUMERIC,2) AS avg_sum_race
FROM total_users_race AS tur 
JOIN total_pay_users_race AS tpur ON tur.race_id=tpur.race_id
JOIN fantasy.users AS e ON   tpur.race_id=e.race_id
JOIN activiti_users_race AS aur ON e.id=aur.id
JOIN fantasy.race AS r ON e.race_id=r.race_id
ORDER BY total_users DESC;
-- Задача 2: Частота покупок
-- Напишите ваш запрос здесь
