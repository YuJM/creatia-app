# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'

class TaskCalendarServiceImproved
  include Dry::Monads[:result, :do]
  
  pattr_initialize [:user!, :organization!, :filters]
  memo_wise :tasks_scope
  
  def call
    calendar = yield create_calendar
    yield add_tasks(calendar)
    yield add_sprints(calendar) 
    yield add_milestones(calendar)
    
    Success(calendar.to_ical)
  rescue => e
    Failure([:calendar_error, e.message])
  end
  
  private
  
  def create_calendar
    cal = Icalendar::Calendar.new
    cal.append_custom_property("X-WR-CALNAME", calendar_name)
    cal.append_custom_property("X-WR-TIMEZONE", "Asia/Seoul")
    cal.append_custom_property("X-WR-CALDESC", "Creatia Project Management")
    
    Success(cal)
  rescue => e
    Failure([:setup_error, e.message])
  end
  
  def add_tasks(calendar)
    tasks_scope.each do |task|
      event = build_task_event(task)
      calendar.add_event(event)
    end
    
    Success(calendar)
  rescue => e
    Failure([:task_error, e.message])
  end
  
  def add_sprints(calendar)
    Sprint.where(
      organization_id: organization.id,
      status: 'active'
    ).each do |sprint|
      add_sprint_events(calendar, sprint)
    end
    
    Success(calendar)
  rescue => e
    Failure([:sprint_error, e.message])
  end
  
  def add_milestones(calendar)
    Milestone.upcoming.find_each do |milestone|
      event = build_milestone_event(milestone)
      calendar.add_event(event)
    end
    
    Success(calendar)
  rescue => e
    Failure([:milestone_error, e.message])
  end
  
  memo_wise
  def tasks_scope
    scope = Task.where(
      organization_id: organization.id,
      assignee_id: user.id
    )
    scope = scope.where(sprint_id: filters[:sprint_id]) if filters&.dig(:sprint_id)
    scope = scope.where(service_id: filters[:service_id]) if filters&.dig(:service_id)
    scope
  end
  
  def calendar_name
    if filters&.dig(:sprint_id)
      "Sprint Calendar - #{Sprint.find(filters[:sprint_id]).name}"
    elsif filters&.dig(:service_id)
      "Service Calendar - #{Service.find(filters[:service_id]).name}"
    else
      "#{user.name} - Creatia Tasks"
    end
  end
  
  def build_task_event(task)
    Icalendar::Event.new.tap do |e|
      e.dtstart = Icalendar::Values::DateTime.new(task.start_time || task.created_at)
      e.dtend = Icalendar::Values::DateTime.new(task.deadline || task.start_time + 1.hour)
      e.summary = "#{task.task_id}: #{task.title}"
      e.description = task.description
      e.uid = "task-#{task.id}@creatia.io"
      
      # 우선순위별 색상
      e.append_custom_property("COLOR", urgency_color(task))
      
      # 알림 추가
      add_alarms(e, task) if task.deadline
    end
  end
  
  def build_milestone_event(milestone)
    Icalendar::Event.new.tap do |e|
      e.dtstart = Icalendar::Values::Date.new(milestone.target_date)
      e.dtend = Icalendar::Values::Date.new(milestone.target_date)
      e.summary = "🎯 Milestone: #{milestone.name}"
      e.description = "Progress: #{milestone.progress}%\n#{milestone.description}"
      e.categories = ["milestone", milestone.status]
    end
  end
  
  def add_sprint_events(calendar, sprint)
    # Sprint 시작 이벤트
    calendar.event do |e|
      e.dtstart = sprint.start_date
      e.summary = "🚀 Sprint Start: #{sprint.name}"
      e.description = "Sprint Goal: #{sprint.goal}"
    end
    
    # Daily Standup 반복 이벤트
    add_recurring_standup(calendar, sprint) if sprint.daily_standup_time
    
    # Sprint Review 이벤트
    add_sprint_review(calendar, sprint) if sprint.review_meeting_time
  end
  
  def urgency_color(task)
    {
      critical: "#FF0000",
      high: "#FFA500", 
      medium: "#FFFF00",
      low: "#00FF00"
    }[task.urgency_level] || "#0099FF"
  end
  
  def add_alarms(event, task)
    # 1시간 전 알림
    event.alarm do |a|
      a.action = "DISPLAY"
      a.summary = "Task deadline in 1 hour"
      a.trigger = "-PT1H"
    end
    
    # 긴급 작업은 하루 전 알림 추가
    if [:critical, :high].include?(task.urgency_level)
      event.alarm do |a|
        a.action = "DISPLAY"
        a.summary = "Task deadline tomorrow"
        a.trigger = "-PT24H"
      end
    end
  end
end