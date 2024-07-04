import pyarrow.parquet as pq
from ast import literal_eval

class SalaryReport:
    """
    Класс для чтения и обработки исходных файлов в отчет по средним зарплатам

    Атрибуты:
    employees_dict - полученный из файла словарь вида
        ID сотрудника (int): ФИО (str)
    salary_dict - полученый из файла словарь вида
        ID сотрудника (int): [сред.зарплата (float), сред.бонус (float)]
    emails_dict - полученный из файла словарь вида
        ID сотрудника (int): {email1, email2, ...} 

    Методы:
    display_report - подсчет и вывод отчета вида
        ID сотрудника, ФИО, сред.зарплата, сред.бонус, email
        для каждого email выводится отдельная строка
    """
    def __init__(
        self, 
        employees_path, 
        salary_path,
        emails_path,
        dt_begin,
        dt_end):
        """
        emails_path: str - путь к файлу c адресами электронных почт сотрудников (формат parquet)
        employees_path: str - путь к файлу с ФИО сотрудников (формат txt)
        salary_path: str - путь к файлу с данными по зарплатам (формат csv)
        dt_begin: str - дата начала периода отчета ГГГГ-ММ-ДД
        dt_end: str - дата окончания периода отчета ГГГГ-ММ-ДД
        """
        #Чтение файлов, получение словарей с данными 
        self.emails_dict = self.get_emails_dict(emails_path)
        self.salary_dict = self.get_salary_dict(salary_path, dt_begin, dt_end)
        self.employees_dict = self.get_employees_dict(employees_path)

    def get_employees_dict(self, employees_path, var_name='employees'):
        """
        Чтение файла с ФИО сотрудников, получение словаря вида
            ID сотрудника (int): ФИО (str)
        Параметры:
            employees_path - путь к файлу с ФИО сотрудников
            var_name - ключевое слово в файле с нужным списком
        """
        #Читаем только нужные строки из файла, соответствующие ключевому слову
        with open(employees_path) as file: 
            lines_matched = []
            start_flg = False
            for line in file:
                if not start_flg and line.strip()[:len(var_name)] == var_name:
                    start_flg = True
                elif start_flg and line.strip()[:1] != ']':
                    lines_matched.append(line.strip())
                elif start_flg and line.strip()[:1] == ']':
                    break
        #Обрабатываем полученные строки, возвращаем словарь нужного формата
        return {literal_eval(x[:-1])[0]: " ".join(literal_eval(x[:-1])[1:4]) 
                for x in lines_matched}

    def get_salary_dict(self, salary_path, dt_begin, dt_end):
        """
        Чтение файла с зарплатами сотрудников, получение словаря вида
            ID сотрудника (int): [сред.зарплата (float), сред.бонус (float)]
            отфильтрованный за нужные даты
        Параметры:
            salary_path - путь к файлу с данными по зарплатам
            dt_begin - дата начала периода отчета
            dt_end - дата окончания периода отчета
        """
        salary_dict = {}
        with open(salary_path) as file:
            for line in file:
                id, date, type, value = line.strip().split(';')[:4]
                #проверяем каждую строку на валидность, в т.ч. соответсвие датам отчета
                if id.isdigit() and date >= dt_begin and date <= dt_end:
                    id = int(id)
                    value = float(value)
                    #итеративно записываем в словарь суммы и их количество 
                    if not id in salary_dict:
                        salary_dict[id] = {'salary':[0.0, 0], 'bonus':[0.0, 0]}
                    salary_dict[id][type][0] += value
                    salary_dict[id][type][1] += 1
        #считаем результативные значения
        return {id: [value['salary'][0] / (value['salary'][1] or 1), 
                        value['bonus'][0]/(value['bonus'][1] or 1)] 
                for id, value in salary_dict.items()}

    def get_emails_dict(self, emails_path):
        """
        Чтение файла с адресами эл.почт сотрудников, получение словаря вида
            ID сотрудника (int): {email1, email2, ...}
        Параметры:
            emails_path - путь к файлу с данными по зарплатам
        """
        emails_pq = pq.read_table(emails_path)
        emails_dict = {}
        for line in emails_pq.to_pylist():
            #в словарь записываем id сотрудника, итеративно дополняем сет адресов почт
            if int(line['PERSON_ID']) not in emails_dict:
                emails_dict[int(line['PERSON_ID'])] = set()
            emails_dict[int(line['PERSON_ID'])].add(line['EMAIL'])
        return emails_dict

    def display_report(self):
        """
        Подготовка и вывод отчета вида
            ID сотрудника, ФИО, сред.зарплата, сред.бонус, email
        """
        for key, value in self.employees_dict.items():
            #соединение строки из employees_dict со строкой из salary_dict по id сотрудника
            salary, bonus = self.salary_dict.get(key)
            line = [key,
                    value,
                    salary,
                    bonus
                    ]
            #если есть e-mail для сотрудника, присоединяем к строке вывода
            #и выводим итеративно по количеству email-ов
            if self.emails_dict.get(key):
                for email in self.emails_dict.get(key):
                    line.append(email)
                    print(', '.join([str(x) for x in line]))
                    line.pop(-1)
            #если e-mail не найден, выводим без него 
            else:
                print(', '.join([str(x) for x in line]))

report = SalaryReport(
      employees_path='employess_dict.txt',
      salary_path='salary.csv',
      emails_path='emails.gzip',
      dt_begin='2020-01-01',
      dt_end='2020-12-31')

report.display_report()
