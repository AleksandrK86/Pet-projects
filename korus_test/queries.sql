/*
	1. Сформировать список студентов, поступивших в университет в 2022 году,
	даты рождения которых приходятся на 1 полугодие 2007 года. 
	В список вывести ID студента, его ФИО, дату рождения, факультет
	и дату поступления.
*/

SELECT
	id_student,
	fio,
	dob,
	faculty,
	enrollment_date
FROM
	student
WHERE
	DATE_PART('YEAR', enrollment_date) = '2022'
	AND dob BETWEEN '2007-01-01' AND '2007-06-30';

/*
	2. Вывести список ведомостей 2022 календарного года в следующем формате:
	дата ведомости, ID ведомости, ФИО студента, ФИО преподавателя, 
	сдаваемый предмет, форму контроля, оценка. В случае, если у студента
	оценка равна “не зачтено”, то необходимо изменить ее на ‘-’, “зачтено” на ‘+’,
	а “отл”, “хор”, “удовл” на 5, 4, 3 соответственно.
*/

SELECT
	s."date",
	s.id_statement,
	stud.fio 		AS student_fio,
	lect.fio 		AS lecturer_fio,
	s.subject,
	s."control",
	CASE
		WHEN s.grade = 'не зачтено' THEN '-'
		WHEN s.grade = 'зачтено' 	THEN '+'
		WHEN s.grade = 'отл' 		THEN '5'
		WHEN s.grade = 'хор' 		THEN '4'
		WHEN s.grade = 'удовл' 		THEN '3'
		ELSE s.grade
	END AS grade
FROM
	"statement" s
LEFT JOIN student stud
	ON s.id_student = stud.id_student
LEFT JOIN lecturer lect
	ON s.id_lecturer = lect.id_lecturer
WHERE
	DATE_PART('YEAR', s."date") = '2022'
ORDER BY
	s."date",
	s.id_statement;

/*
	3. Сформировать список групп обучения, в которых среднее фактическое количество часов больше 70
	в рамках 1 семестра учебного года. В отчет вывести: название группы обучения, факультет, год,
	семестр, среднее фактическое количество часов. Список необходимо отсортировать по убыванию среднего 
	фактического количества часов.
*/


SELECT
	sg."name",
	sp.faculty,
	sq."year",
	sq.semester,
	sq.fact_avg
FROM
	(SELECT
		id_group,
		"year",
		semester,
		AVG(fact) AS fact_avg
	FROM
		ed_plan
	WHERE
		semester = 1
	GROUP BY
		id_group,
		"year",
		semester
	HAVING
		avg(fact) > 70
	) sq
LEFT JOIN
	study_group sg
	ON sq.id_group = sg.id_group
LEFT JOIN
	specialty sp
	ON sg.id_specialty = sp.id_specialty
ORDER BY
	fact_avg DESC;

/*
	4. Определить список научных руководителей, которые на текущий момент (на сегодня) имеют наибольшее
	активное число студентов на научном руководстве. В сформированном списке необходимо отобразить
	ФИО научного руководителя, количество активных студентов, дату формирования запроса.
	Сортировка списка должна быть выполнена по возрастанию количества активных студентов.
*/

SELECT
	scientific_director,
	count(DISTINCT id_student) 	AS actual_students_cnt,
	now()::date					AS dt
FROM
	student
WHERE
	enrollment_date <= now()::date --случай, когда студент только запланирован к зачислению
	AND (date_deduction IS NULL
		OR date_deduction > now()::date --случай, когда студент будет отчислен, но на тек.момент еще активен
		OR enrollment_date > date_deduction --случай, когда студент восстановлен после отчисления
	)
GROUP BY
	scientific_director
ORDER BY
	actual_students_cnt;

/*
	5. Вывести список отчисленных студентов на текущий момент (на сегодня), которые до своего отчисления
	сдавали свои курсовые работы и экзамены только на хорошо и отлично. В сформированном списке необходимо
	вывести ФИО студента, дату зачисления, дату отчисления, дату ведомости о сдаче, предмет и оценку по предмету.
*/

WITH students_deducted_grade AS (
SELECT
	stud.id_student,
	stud.fio,
	stud.enrollment_date,
	stud.date_deduction,
	stat."date",
	stat.subject,
	stat.grade
FROM
	student stud
INNER JOIN
	"statement" stat
	ON stud.id_student = stat.id_student
WHERE
	date_deduction <= now()::date --берем только уже отчисленных студентов
	AND (enrollment_date <= date_deduction
		 OR enrollment_date > now()::date) --если студент восстанавливается после отчисления, берем в расчет только тех, для которых дата восстановления еще не настала
	AND CONTROL IN ('экзамен', 'к/р') --нас интересуют только результаты экзаменов и к/р
)

SELECT
	fio,
	enrollment_date,
	date_deduction,
	"date",
	subject,
	grade
FROM
	students_deducted_grade
WHERE
	id_student NOT IN (SELECT id_student FROM students_deducted_grade WHERE grade = 'удовл');

/*
	6. На основании таблицы “Отчет” для каждого предмета (item) необходимо найти два курса (ed_course) 
	с наименьшим количеством студентов (num_students). 
*/

WITH report_sq AS (
SELECT
	*,
	ROW_NUMBER() OVER(PARTITION BY item ORDER BY num_students) AS num_students_rank
FROM
	report r
)

SELECT
	item,
	ed_course,
	num_students
FROM
	report_sq
WHERE
	num_students_rank <= 2;

/*
	7. На основании данных таблицы “Отчет_2”, которая является копией из таблицы “Отчет”, необходимо
	определить какие строки были утеряны при копировании.
*/

SELECT * FROM report
EXCEPT
SELECT * FROM report_2;
