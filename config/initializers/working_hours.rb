# config/initializers/working_hours.rb
# WorkingHours gem 설정

WorkingHours::Config.working_hours = {
  mon: { '09:00' => '17:00' },  # 8 hours
  tue: { '09:00' => '17:00' },  # 8 hours
  wed: { '09:00' => '17:00' },  # 8 hours
  thu: { '09:00' => '17:00' },  # 8 hours
  fri: { '09:00' => '17:00' }   # 8 hours
}

# 한국 시간대 설정
WorkingHours::Config.time_zone = 'Asia/Seoul'

# 공휴일 설정 (선택적)
# WorkingHours::Config.holidays = [
#   Date.new(2024, 1, 1),  # 신정
#   Date.new(2024, 2, 9),  # 설날
#   Date.new(2024, 2, 10), # 설날
#   Date.new(2024, 2, 11), # 설날
#   Date.new(2024, 3, 1),  # 삼일절
#   Date.new(2024, 5, 5),  # 어린이날
#   Date.new(2024, 6, 6),  # 현충일
#   Date.new(2024, 8, 15), # 광복절
#   Date.new(2024, 9, 16), # 추석
#   Date.new(2024, 9, 17), # 추석
#   Date.new(2024, 9, 18), # 추석
#   Date.new(2024, 10, 3), # 개천절
#   Date.new(2024, 10, 9), # 한글날
#   Date.new(2024, 12, 25) # 성탄절
# ]