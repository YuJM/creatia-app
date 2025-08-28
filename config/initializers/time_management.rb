# Business Time 초기화 설정
BusinessTime::Config.load("#{Rails.root}/config/business_time.yml")
BusinessTime::Config.work_week = [:mon, :tue, :wed, :thu, :fri]

# Working Hours 초기화 설정
WorkingHours::Config.working_hours = {
  mon: {'09:00' => '18:00'},
  tue: {'09:00' => '18:00'},
  wed: {'09:00' => '18:00'},
  thu: {'09:00' => '18:00'},
  fri: {'09:00' => '18:00'}
}

WorkingHours::Config.holidays = [
  Date.new(2025, 1, 1),   # 신정
  Date.new(2025, 1, 28),  # 설날
  Date.new(2025, 1, 29),
  Date.new(2025, 1, 30),
  Date.new(2025, 3, 1),   # 삼일절
  Date.new(2025, 5, 5),   # 어린이날
  Date.new(2025, 5, 6),   # 부처님오신날
  Date.new(2025, 6, 6),   # 현충일
  Date.new(2025, 8, 15),  # 광복절
  Date.new(2025, 10, 6),  # 추석
  Date.new(2025, 10, 7),
  Date.new(2025, 10, 8),
  Date.new(2025, 10, 3),  # 개천절
  Date.new(2025, 10, 9),  # 한글날
  Date.new(2025, 12, 25)  # 크리스마스
]

WorkingHours::Config.time_zone = "Asia/Seoul"

# Chronic 설정
Chronic.time_class = Time.zone if defined?(Time.zone)

# Groupdate 설정
Groupdate.time_zone = "Asia/Seoul"
Groupdate.week_start = :monday