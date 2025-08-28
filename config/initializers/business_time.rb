# config/initializers/business_time.rb
# Business Time gem 설정 - 업무 시간 계산

BusinessTime::Config.load("#{Rails.root}/config/business_time.yml")

# 기본 업무 시간 설정 (월-금, 9AM-6PM)
BusinessTime::Config.beginning_of_workday = "9:00 am"
BusinessTime::Config.end_of_workday = "6:00 pm"

# 한국 공휴일 2024년
BusinessTime::Config.holidays = [
  Date.new(2024, 1, 1),   # 신정
  Date.new(2024, 2, 9),   # 설날 연휴
  Date.new(2024, 2, 10),  # 설날
  Date.new(2024, 2, 11),  # 설날 연휴
  Date.new(2024, 2, 12),  # 대체공휴일
  Date.new(2024, 3, 1),   # 삼일절
  Date.new(2024, 4, 10),  # 국회의원 선거
  Date.new(2024, 5, 5),   # 어린이날
  Date.new(2024, 5, 6),   # 대체공휴일
  Date.new(2024, 5, 15),  # 부처님오신날
  Date.new(2024, 6, 6),   # 현충일
  Date.new(2024, 8, 15),  # 광복절
  Date.new(2024, 9, 16),  # 추석 연휴
  Date.new(2024, 9, 17),  # 추석
  Date.new(2024, 9, 18),  # 추석 연휴
  Date.new(2024, 10, 3),  # 개천절
  Date.new(2024, 10, 9),  # 한글날
  Date.new(2024, 12, 25), # 크리스마스
]

# 시간대 설정은 Rails 타임존 설정을 따름
# Time.zone = "Asia/Seoul"은 config/application.rb에서 설정

# 업무일 계산 헬퍼 메서드들
module BusinessTimeHelpers
  # 다음 업무일 찾기
  def next_business_day(from = Date.current)
    1.business_day.from_now(from)
  end
  
  # 업무 시간만 계산 (점심시간 제외)
  def business_hours_between(start_time, end_time, exclude_lunch: false)
    hours = 0
    current = start_time
    
    while current < end_time
      if current.workday?
        day_start = current.beginning_of_workday
        day_end = current.end_of_workday
        
        # 해당 날짜의 업무 시간 계산
        if current >= day_start && current <= day_end
          worked_end = [end_time, day_end].min
          hours += (worked_end - current) / 1.hour
          
          # 점심시간 제외 (12PM - 1PM)
          if exclude_lunch
            lunch_start = current.change(hour: 12)
            lunch_end = current.change(hour: 13)
            
            if current <= lunch_start && worked_end >= lunch_end
              hours -= 1
            elsif current < lunch_end && worked_end > lunch_start
              overlap = [worked_end, lunch_end].min - [current, lunch_start].max
              hours -= overlap / 1.hour if overlap > 0
            end
          end
        end
      end
      
      current = current.next_business_day.beginning_of_workday
    end
    
    hours
  end
  
  # 마감일까지 남은 업무일
  def business_days_until(target_date, from = Date.current)
    count = 0
    current = from
    
    while current < target_date
      count += 1 if current.workday?
      current = current.next_day
    end
    
    count
  end
  
  # SLA 계산 (Service Level Agreement)
  def sla_deadline(priority, from = Time.current)
    case priority
    when :urgent, "urgent"
      4.business_hours.from_now(from)  # 4시간 내
    when :high, "high"
      1.business_day.from_now(from)     # 1업무일 내
    when :medium, "medium"
      3.business_days.from_now(from)    # 3업무일 내
    when :low, "low"
      5.business_days.from_now(from)    # 5업무일 내
    else
      7.business_days.from_now(from)    # 기본 7업무일
    end
  end
end

# 모든 Time/Date 클래스에 헬퍼 추가
Time.include BusinessTimeHelpers
Date.include BusinessTimeHelpers
DateTime.include BusinessTimeHelpers