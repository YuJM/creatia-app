# app/helpers/time_helper.rb
module TimeHelper
  # Local Time gem을 활용한 시간 표시 헬퍼
  
  # 사용자 시간대에 맞춰 자동으로 변환되는 시간 태그
  def local_time_tag(time, format = :default, **options)
    return content_tag(:span, "—", class: "text-gray-400") if time.blank?
    
    # Local Time gem이 자동으로 처리하도록 time 태그 생성
    time_tag(time, **options.merge(
      data: {
        "local-time": true,
        "format": local_time_format(format)
      }
    ))
  end
  
  # 상대 시간 표시 (예: "2시간 전", "3일 후")
  def relative_time_tag(time, **options)
    return content_tag(:span, "—", class: "text-gray-400") if time.blank?
    
    time_tag(time, time_ago_in_words(time), **options.merge(
      data: {
        "local-time": true,
        "format": "relative"
      }
    ))
  end
  
  # 마감일 표시 (긴급도 스타일링 포함)
  def deadline_tag(deadline, **options)
    return content_tag(:span, "—", class: "text-gray-400") if deadline.blank?
    
    urgency_class = urgency_class_for(deadline)
    
    time_tag(deadline, **options.merge(
      class: [options[:class], urgency_class].compact.join(" "),
      data: {
        "local-time": true,
        "deadline": true,
        "urgency": urgency_level_for(deadline)
      }
    ))
  end
  
  # 포모도로 타이머용 시간 표시
  def pomodoro_timer_tag(seconds, **options)
    minutes = seconds / 60
    remaining_seconds = seconds % 60
    timer_display = format("%02d:%02d", minutes, remaining_seconds)
    
    content_tag(:span, timer_display, **options.merge(
      class: [options[:class], pomodoro_timer_class(seconds)].compact.join(" "),
      data: {
        "pomodoro-timer": true,
        "seconds": seconds
      }
    ))
  end
  
  # 업무 시간 기준 표시
  def business_time_tag(time, **options)
    return content_tag(:span, "—", class: "text-gray-400") if time.blank?
    
    if time.future?
      hours = WorkingHours.working_time_between(Time.current, time) / 1.hour.to_f
      text = business_time_text(hours)
      
      content_tag(:span, text, **options.merge(
        title: time.strftime("%Y-%m-%d %H:%M"),
        data: { "business-time": true }
      ))
    else
      local_time_tag(time, :default, **options)
    end
  end
  
  private
  
  # Local Time 포맷 변환
  def local_time_format(format)
    case format
    when :short then "%m/%d %l:%M%P"
    when :long then "%B %e, %Y %l:%M%P"
    when :date_only then "%B %e, %Y"
    when :time_only then "%l:%M%P"
    when :relative then "relative"
    else "%Y-%m-%d %H:%M"
    end
  end
  
  # 긴급도 레벨 계산
  def urgency_level_for(deadline)
    return :none unless deadline
    
    hours_until = (deadline - Time.current) / 1.hour
    
    case hours_until
    when ..0 then :overdue
    when 0..2 then :critical
    when 2..8 then :high
    when 8..24 then :medium
    else :low
    end
  end
  
  # 긴급도에 따른 CSS 클래스
  def urgency_class_for(deadline)
    case urgency_level_for(deadline)
    when :overdue then "text-red-700 font-bold"
    when :critical then "text-red-600 font-semibold"
    when :high then "text-orange-600 font-semibold"
    when :medium then "text-yellow-600"
    when :low then "text-gray-600"
    else "text-gray-500"
    end
  end
  
  # 포모도로 타이머 CSS 클래스
  def pomodoro_timer_class(seconds)
    if seconds <= 60
      "text-red-600 animate-pulse font-mono text-2xl"
    elsif seconds <= 300
      "text-orange-600 font-mono text-2xl"
    else
      "text-gray-700 dark:text-gray-300 font-mono text-2xl"
    end
  end
  
  # 업무 시간 텍스트
  def business_time_text(hours)
    if hours < 1
      "#{(hours * 60).round}분 (업무시간)"
    elsif hours < 8
      "#{hours.round(1)}시간 (업무시간)"
    else
      business_days = (hours / 8.0).round(1)
      "#{business_days}일 (업무일)"
    end
  end
end