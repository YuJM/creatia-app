# FlexibleSchedule - 유연한 스프린트 일정 관리
#
# 스프린트의 시작/종료 시간을 유연하게 관리하고
# 팀별 맞춤 업무 시간을 지원하는 모듈
module FlexibleSchedule
  extend ActiveSupport::Concern
  
  included do
    # 기본 업무 시간 상수
    DEFAULT_START_TIME = "09:00"
    DEFAULT_END_TIME = "18:00"
    DEFAULT_LUNCH_START = "12:00"
    DEFAULT_LUNCH_END = "13:00"
    
    # 유연 근무제 시간 범위
    FLEX_EARLIEST_START = "06:00"
    FLEX_LATEST_END = "23:00"
    
    # 스크럼 이벤트 기본 시간
    DEFAULT_STANDUP_TIME = "10:00"
    DEFAULT_PLANNING_DURATION = 4.hours
    DEFAULT_REVIEW_DURATION = 2.hours
    DEFAULT_RETROSPECTIVE_DURATION = 1.5.hours
  end
  
  # 유연한 스프린트 일정 프리셋
  module Presets
    # 일반 업무 시간 (9 to 6)
    STANDARD = {
      start_time: "09:00",
      end_time: "18:00",
      flexible_hours: false,
      weekend_work: false,
      daily_standup_time: "10:00"
    }.freeze
    
    # 스타트업 모드 (유연한 시간, 주말 가능)
    STARTUP = {
      start_time: "10:00",
      end_time: "20:00",
      flexible_hours: true,
      weekend_work: true,
      daily_standup_time: "11:00"
    }.freeze
    
    # 리모트 팀 (매우 유연한 시간)
    REMOTE = {
      start_time: "07:00",
      end_time: "22:00",
      flexible_hours: true,
      weekend_work: false,
      daily_standup_time: "10:00"
    }.freeze
    
    # 글로벌 팀 (시차 고려)
    GLOBAL = {
      start_time: "06:00",
      end_time: "23:00",
      flexible_hours: true,
      weekend_work: false,
      daily_standup_time: nil  # 비동기 스탠드업
    }.freeze
    
    # 집중 개발 모드 (크런치 타임)
    CRUNCH = {
      start_time: "08:00",
      end_time: "22:00",
      flexible_hours: true,
      weekend_work: true,
      daily_standup_time: "09:00"
    }.freeze
  end
  
  # 프리셋 적용
  def apply_schedule_preset(preset_name)
    preset = case preset_name.to_sym
             when :standard then Presets::STANDARD
             when :startup then Presets::STARTUP
             when :remote then Presets::REMOTE
             when :global then Presets::GLOBAL
             when :crunch then Presets::CRUNCH
             else
               raise ArgumentError, "Unknown preset: #{preset_name}"
             end
    
    assign_attributes(preset)
    save
  end
  
  # 팀별 커스텀 스케줄 설정
  def set_team_schedule(team_preferences)
    # team_preferences 예시:
    # {
    #   monday: { start: "10:00", end: "19:00", standup: "10:30" },
    #   tuesday: { start: "09:00", end: "18:00", standup: "09:30" },
    #   wednesday: { start: "10:00", end: "19:00", standup: "10:30" },
    #   thursday: { start: "09:00", end: "18:00", standup: "09:30" },
    #   friday: { start: "09:00", end: "15:00", standup: "09:30" },
    #   timezone: "Asia/Seoul"
    # }
    
    self.custom_schedule = team_preferences
    self.flexible_hours = true
    save
  end
  
  # 특정 날짜의 업무 시간 가져오기
  def working_hours_for(date)
    return default_working_hours unless custom_schedule
    
    day_name = date.strftime("%A").downcase.to_sym
    day_schedule = custom_schedule[day_name.to_s] || custom_schedule[day_name]
    
    if day_schedule
      {
        start: Time.zone.parse(day_schedule["start"] || day_schedule[:start]),
        end: Time.zone.parse(day_schedule["end"] || day_schedule[:end]),
        standup: day_schedule["standup"] || day_schedule[:standup]
      }
    else
      default_working_hours
    end
  end
  
  # 스프린트 기간 중 총 작업 가능 시간 (유연한 시간 고려)
  def total_available_hours
    return 0 unless start_date && end_date
    
    total_hours = 0
    current_date = start_date
    
    while current_date <= end_date
      if should_work_on?(current_date)
        hours = working_hours_for(current_date)
        day_hours = calculate_day_hours(hours[:start], hours[:end])
        total_hours += day_hours
      end
      
      current_date += 1.day
    end
    
    total_hours
  end
  
  # 특정 날짜에 근무하는지 확인
  def should_work_on?(date)
    if weekend_work
      true  # 주말 포함 모든 날 근무
    elsif flexible_hours && custom_schedule
      # 커스텀 스케줄 확인
      day_schedule = custom_schedule[date.strftime("%A").downcase]
      day_schedule.present?
    else
      date.on_weekday?  # 평일만
    end
  end
  
  # 스프린트 스케줄 요약
  def schedule_summary
    if flexible_hours
      if custom_schedule.present?
        "커스텀 스케줄 (팀별 설정)"
      else
        "유연 근무 (#{start_time&.strftime('%H:%M') || '07:00'} - #{end_time&.strftime('%H:%M') || '22:00'})"
      end
    else
      "표준 근무 (#{start_time&.strftime('%H:%M') || '09:00'} - #{end_time&.strftime('%H:%M') || '18:00'})"
    end
  end
  
  # 스크럼 이벤트 자동 스케줄링
  def schedule_scrum_events
    return unless start_date && end_date
    
    # 스프린트 계획 미팅 (첫날)
    planning_time = sprint_datetime(start_date, start_time || Time.zone.parse(DEFAULT_START_TIME))
    
    # 스프린트 리뷰 (마지막날 오후)
    self.review_meeting_time = sprint_datetime(
      end_date, 
      Time.zone.parse("14:00")
    )
    
    # 회고 미팅 (리뷰 후)
    self.retrospective_time = review_meeting_time + 2.hours if review_meeting_time
    
    save
  end
  
  # 다음 스크럼 이벤트
  def next_scrum_event
    events = []
    
    # 데일리 스탠드업
    if daily_standup_time && (standup = next_standup_time) && standup > Time.current
      events << { type: :standup, time: standup, duration: 15.minutes }
    end
    
    # 스프린트 리뷰
    if review_meeting_time && review_meeting_time > Time.current
      events << { type: :review, time: review_meeting_time, duration: DEFAULT_REVIEW_DURATION }
    end
    
    # 회고
    if retrospective_time && retrospective_time > Time.current
      events << { type: :retrospective, time: retrospective_time, duration: DEFAULT_RETROSPECTIVE_DURATION }
    end
    
    events.min_by { |e| e[:time] }
  end
  
  # 팀 생산성 최적 시간대 분석 (Groupdate 활용)
  def optimal_working_hours_analysis
    return {} unless tasks.any?
    
    # 시간대별 완료 태스크 분석
    completed_by_hour = tasks
      .done
      .group_by_hour_of_day(:updated_at, format: "%H:00")
      .count
    
    # 생산성 점수 계산
    productivity_scores = completed_by_hour.map do |hour, count|
      hour_int = hour.to_i
      score = count
      
      # 업무 시간 내 가중치
      if hour_int.between?(9, 18)
        score *= 1.2
      elsif hour_int.between?(7, 9) || hour_int.between?(18, 20)
        score *= 1.0
      else
        score *= 0.7  # 야근/새벽 패널티
      end
      
      [hour, score.round(1)]
    end.to_h
    
    {
      peak_hours: productivity_scores.max_by(3) { |_, score| score },
      recommended_standup: recommend_standup_time(productivity_scores),
      recommended_focus_time: recommend_focus_blocks(productivity_scores)
    }
  end
  
  private
  
  def default_working_hours
    {
      start: Time.zone.parse(start_time&.strftime('%H:%M') || DEFAULT_START_TIME),
      end: Time.zone.parse(end_time&.strftime('%H:%M') || DEFAULT_END_TIME),
      standup: daily_standup_time
    }
  end
  
  def calculate_day_hours(start_time, end_time)
    return 0 unless start_time && end_time
    
    hours = (end_time - start_time) / 1.hour
    # 6시간 이상 근무 시 점심시간 제외
    hours > 6 ? hours - 1 : hours
  end
  
  def recommend_standup_time(productivity_scores)
    # 오전 중 생산성이 높은 시간 찾기
    morning_scores = productivity_scores.select { |hour, _| hour.to_i.between?(9, 11) }
    
    if morning_scores.any?
      best_hour = morning_scores.min_by { |_, score| score }.first
      "#{best_hour} (생산성 방해 최소화)"
    else
      "10:00 (기본 권장)"
    end
  end
  
  def recommend_focus_blocks(productivity_scores)
    # 상위 3개 생산성 시간대
    top_hours = productivity_scores.max_by(3) { |_, score| score }
    
    top_hours.map do |hour, score|
      {
        time: hour,
        recommendation: focus_recommendation(hour.to_i),
        score: score
      }
    end
  end
  
  def focus_recommendation(hour)
    case hour
    when 9..11
      "복잡한 문제 해결에 적합"
    when 14..16
      "창의적 작업에 적합"
    when 16..18
      "코드 리뷰 및 협업에 적합"
    else
      "간단한 작업 처리"
    end
  end
end