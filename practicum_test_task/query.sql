Текст SQL-запроса на диалекте PostgreSQL (работоспособность протестирована на сгенерированных исходных данных):

/* Запрос на выявление бага подозрительно быстрого прохождения уроков:
* выгружает данные о прохождении студентами уроков, после завершения которых 
* прошло не более 7 секунд до успешного завершения следующей темы.
* 
* Учитываются только данные по профессии "data-analyst"
* страны "Serbia" апрельской когорты 2022 года.
* 
* Исходные таблицы: finished_lesson_test, lesson_index_test
* 
* Схема результирующей таблицы:
* 
* delta seconds - разница в секундах между временем прохождения следующего урока и текущего
* lesson_datetime - время завершения урока студентом
* lesson_id – ID урока
* next_lesson_datetime - время прохождения следующего урока
* profession_name - наименование профессии
* user_id - ID прошедшего урок студента
*/

WITH analyst_serbia_test AS (
SELECT 
  id, 
  date_created, 
  t1.lesson_id, 
  profession_id, 
  profession_name, 
  user_id
FROM finished_lesson_test t1
INNER JOIN (
  SELECT 
    lesson_id, 
    profession_id, 
    profession_name
  FROM
    lesson_index_test 
  WHERE
    country = 'Serbia' AND profession_name = 'data-analyst'
) t2
  ON t1.lesson_id = t2.lesson_id
),

test_filtered AS (
SELECT 
  id,
  date_created,
  lesson_id,
  LEAD(date_created) OVER(PARTITION BY user_id, profession_id ORDER BY date_created) AS next_lesson_datetime,
  profession_name,
  user_id
FROM
  analyst_serbia_test
WHERE
  user_id IN (SELECT user_id FROM analyst_serbia_test GROUP BY user_id HAVING MIN(CAST(date_created AS DATE)) BETWEEN '2022-04-01' AND '2022-04-30')
)

SELECT
  EXTRACT(EPOCH FROM AGE(next_lesson_datetime, date_created)) AS delta_seconds,
  date_created AS lesson_datetime,
  lesson_id,
  next_lesson_datetime,
  profession_name,
  user_id
FROM 
  test_filtered
WHERE
  EXTRACT(EPOCH FROM (next_lesson_datetime - date_created)) <= 7
ORDER BY
  lesson_datetime, delta_seconds, user_id
