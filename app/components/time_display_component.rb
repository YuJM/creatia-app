# TimeDisplayComponent - 시간 표시 ViewComponent
#
# local_time gem과 함께 사용되어 사용자 타임존에 맞는 시간을 표시
# 다양한 형식의 시간 표시를 지원하는 재사용 가능한 컴포넌트
#
class TimeDisplayComponent < ViewComponent::Base
  include ApplicationHelper
  
  attr_reader :time, :format, :options
  
  FORMATS = {
    default: "%Y-%m-%d %H:%M",
    short: "%m/%d %H:%M",
    long: "%Y년 %m월 %d일 %H시 %M분",
    date_only: "%Y-%m-%d",
    time_only: "%H:%M",
    relative: :relative,
    business: :business,
    pomodoro: :pomodoro,
    deadline: :deadline,
    human: :human
  }.freeze
  
  def initialize(time:, format: :default, **options)
    @time = time
    @format = format
    @options = options
    
    super
  end
  
  def call
    return content_tag(:span, "—", class: "text-gray-400") if time.blank?
    
    case FORMATS[format]
    when :relative
      relative_time_display
    when :business
      business_time_display
    when :pomodoro
      pomodoro_time_display
    when :deadline
      deadline_display
    when :human
      human_readable_display
    else
      formatted_time_display
    end
  end
  
  private
  
  # 상대 시간 표시 (예: "2시간 전", "3일 후")
  def relative_time_display
    tag.time(
      time_ago_or_time_to_come,
      datetime: time.iso8601,
      title: time.strftime(FORMATS[:default]),
      class: time_css_classes,
      data: { 
        controller: "local-time",
        local_time_type: "relative"
      }
    )
  end
  
  # 비즈니스 시간 표시 (업무 시간 기준)
  def business_time_display
    if time.future?
      business_time_until = calculate_business_time_until(time)
      tag.span(
        business_time_until,
        title: time.strftime(FORMATS[:default]),
        class: "text-blue-600 dark:text-blue-400",
        data: { business_time: true }
      )
    else
      formatted_time_display
    end
  end
  
  # 포모도로 타이머 표시 (MM:SS 형식)
  def pomodoro_time_display
    seconds = options[:seconds] || 0
    minutes = seconds / 60
    remaining_seconds = seconds % 60
    
    timer_display = format("%02d:%02d", minutes, remaining_seconds)
    
    tag.span(
      timer_display,
      class: pomodoro_css_classes(seconds),
      data: {
        controller: "pomodoro-timer",
        pomodoro_timer_seconds_value: seconds
      }
    )
  end
  
  # 마감일 표시 (긴급도에 따른 스타일)
  def deadline_display
    content = time_with_urgency_indicator
    
    tag.div(class: "flex items-center gap-2") do
      concat urgency_icon
      concat tag.time(
        content,
        datetime: time.iso8601,
        class: deadline_css_classes,
        data: { deadline: true }
      )
    end
  end
  
  # 사람이 읽기 쉬운 형식 (오늘, 내일, 이번 주 등)
  def human_readable_display
    text = case time.to_date
           when Date.today
             "오늘 #{time.strftime('%H:%M')}"
           when Date.tomorrow
             "내일 #{time.strftime('%H:%M')}"
           when Date.yesterday
             "어제 #{time.strftime('%H:%M')}"
           when Date.today.beginning_of_week..Date.today.end_of_week
             "#{time.strftime('%A')} #{time.strftime('%H:%M')}"
           else
             time.strftime(FORMATS[:long])
           end
    
    tag.time(
      text,
      datetime: time.iso8601,
      title: time.strftime(FORMATS[:default]),
      class: "text-gray-700 dark:text-gray-300"
    )
  end
  
  # 기본 형식 시간 표시
  def formatted_time_display
    tag.time(
      time.strftime(FORMATS[format] || format),
      datetime: time.iso8601,
      class: "text-gray-600 dark:text-gray-400",
      data: { 
        controller: "local-time",
        local_time_format: format
      }
    )
  end
  
  # 상대 시간 계산
  def time_ago_or_time_to_come
    if time.past?
      time_ago_in_words(time) + " 전"
    else
      time_ago_in_words(time) + " 후"
    end
  end
  
  # 비즈니스 시간 계산
  def calculate_business_time_until(target_time)
    business_hours = BusinessTime::Config.business_hours_until(target_time)
    
    if business_hours < 1
      "#{(business_hours * 60).round}분 (업무시간)"
    elsif business_hours < 8
      "#{business_hours.round(1)}시간 (업무시간)"
    else
      business_days = (business_hours / 8.0).round(1)
      "#{business_days}일 (업무일)"
    end
  end
  
  # 긴급도 아이콘
  def urgency_icon
    return "" unless options[:show_urgency]
    
    urgency_level = options[:urgency_level] || calculate_urgency_level
    
    case urgency_level
    when :critical
      tag.span("🚨", class: "text-red-500", title: "긴급")
    when :high
      tag.span("⚠️", class: "text-orange-500", title: "높음")
    when :medium
      tag.span("📅", class: "text-yellow-500", title: "보통")
    when :low
      tag.span("📌", class: "text-blue-500", title: "낮음")
    else
      ""
    end
  end
  
  # 긴급도 계산
  def calculate_urgency_level
    return :low unless time.future?
    
    hours_until = (time - Time.current) / 1.hour
    
    case hours_until
    when 0..2
      :critical
    when 2..8
      :high
    when 8..24
      :medium
    else
      :low
    end
  end
  
  # 시간 관련 CSS 클래스
  def time_css_classes
    classes = ["time-display"]
    
    if time.past?
      classes << "text-gray-500"
    elsif time < 1.hour.from_now
      classes << "text-red-600 font-semibold"
    elsif time < 1.day.from_now
      classes << "text-orange-600"
    else
      classes << "text-gray-600"
    end
    
    classes.join(" ")
  end
  
  # 포모도로 CSS 클래스
  def pomodoro_css_classes(seconds)
    classes = ["font-mono text-2xl"]
    
    if seconds <= 60
      classes << "text-red-600 animate-pulse"
    elsif seconds <= 300
      classes << "text-orange-600"
    else
      classes << "text-gray-700 dark:text-gray-300"
    end
    
    classes.join(" ")
  end
  
  # 마감일 CSS 클래스
  def deadline_css_classes
    urgency_level = options[:urgency_level] || calculate_urgency_level
    
    base_classes = ["deadline-display"]
    
    urgency_classes = case urgency_level
                      when :critical
                        "text-red-600 font-bold"
                      when :high
                        "text-orange-600 font-semibold"
                      when :medium
                        "text-yellow-600"
                      when :low
                        "text-gray-600"
                      else
                        "text-gray-500"
                      end
    
    "#{base_classes.join(' ')} #{urgency_classes}"
  end
  
  # 긴급도가 포함된 시간 표시
  def time_with_urgency_indicator
    if time.today?
      "오늘 #{time.strftime('%H:%M')}"
    elsif time.tomorrow?
      "내일 #{time.strftime('%H:%M')}"
    elsif time < 1.week.from_now
      time.strftime('%m월 %d일 %H:%M')
    else
      time.strftime(FORMATS[:default])
    end
  end
  
  # Rails time helper
  def time_ago_in_words(time)
    distance_in_minutes = ((Time.current - time) / 60.0).abs.round
    
    case distance_in_minutes
    when 0..1
      "1분"
    when 2..44
      "#{distance_in_minutes}분"
    when 45..89
      "1시간"
    when 90..1439
      "#{(distance_in_minutes / 60.0).round}시간"
    when 1440..2879
      "1일"
    when 2880..43199
      "#{(distance_in_minutes / 1440.0).round}일"
    when 43200..86399
      "1개월"
    when 86400..525599
      "#{(distance_in_minutes / 43200.0).round}개월"
    else
      "#{(distance_in_minutes / 525600.0).round}년"
    end
  end
end