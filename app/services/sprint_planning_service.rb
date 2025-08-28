# frozen_string_literal: true

require 'memo_wise'
require 'dry/monads'
require 'attr_extras'

class SprintPlanningService
  prepend MemoWise
  include Dry::Monads[:result, :do]
  
  attr_reader :sprint, :team_members
  
  def initialize(sprint, team_members)
    @sprint = sprint
    @team_members = team_members
  end
  
  def execute
    contract = SprintPlanningContract.new
    validation = contract.call(sprint_data)
    
    return Failure([:validation_error, validation.errors.to_h]) if validation.failure?
    
    ActiveRecord::Base.transaction do
      allocations = allocate_tasks
      capacity = calculate_capacity
      risks = identify_risks
      burndown = generate_burndown_projection
      
      plan = SprintPlan.new(
        sprint: sprint,
        allocations: allocations,
        capacity: capacity,
        risks: risks,
        burndown: burndown
      )
      
      Success(plan)
    end
  rescue => e
    Failure([:unexpected_error, e.message])
  end
  
  private
  
  def dependency_analyzer
    @dependency_analyzer ||= DependencyAnalyzer.new(sprint)
  end
  
  def allocate_tasks
    allocations = {}
    unassigned_tasks = sprint.tasks.where(assignee_id: nil)
    
    # 크리티컬 패스 태스크 우선 할당
    critical_tasks = dependency_analyzer.critical_path
    
    critical_tasks.each do |task|
      next if task.assignee_id
      
      # 가장 여유 있는 팀원에게 할당
      assignee = find_least_loaded_member
      if assignee
        allocations[assignee.id] ||= []
        allocations[assignee.id] << task
      end
    end
    
    # 나머지 태스크 할당
    unassigned_tasks.each do |task|
      next if critical_tasks.include?(task)
      
      assignee = find_least_loaded_member
      if assignee
        allocations[assignee.id] ||= []
        allocations[assignee.id] << task
      end
    end
    
    allocations
  end
  
  def calculate_capacity
    team_members.sum do |member|
      # 스프린트 기간 동안의 작업 가능 시간 계산
      working_days = business_days_between(sprint.start_date, sprint.end_date)
      daily_hours = member.respond_to?(:daily_hours) ? member.daily_hours : 8.0
      
      # 회의, 휴식 등을 고려한 실제 작업 가능 시간 (80%)
      working_days * daily_hours * 0.8
    end
  end
  
  def identify_risks
    risks = []
    
    # DependencyAnalyzer의 리스크 평가 활용
    analyzer_risks = dependency_analyzer.risk_assessment
    risks.concat(analyzer_risks)
    
    # 용량 리스크
    total_estimated = sprint.tasks.sum(:estimated_hours) || 0
    capacity = calculate_capacity
    
    if capacity > 0 && total_estimated > capacity * 0.8
      utilization = (total_estimated / capacity * 100).round
      risks << {
        type: 'capacity',
        severity: utilization > 100 ? 'high' : 'medium',
        message: "예상 작업량이 팀 용량의 #{utilization}%입니다",
        mitigation: utilization > 100 ? 
          "작업을 다음 스프린트로 이동하거나 팀원을 추가하세요" :
          "버퍼 시간이 부족합니다. 우선순위를 명확히 하세요"
      }
    end
    
    # 팀 리스크
    if team_members.size < 2
      risks << {
        type: 'team',
        severity: 'medium',
        message: "팀 규모가 작아 리스크 대응이 어렵습니다",
        mitigation: "백업 담당자를 지정하거나 팀원을 추가하세요"
      }
    end
    
    risks
  end
  
  def generate_burndown_projection
    total_hours = sprint.tasks.sum(:estimated_hours) || 0
    working_days = business_days_between(sprint.start_date, sprint.end_date)
    
    return {} if working_days.zero?
    
    daily_velocity = calculate_velocity
    ideal_burndown = []
    projected_burndown = []
    
    (0..working_days).each do |day|
      ideal_hours = total_hours - (total_hours.to_f / working_days * day)
      ideal_burndown << {
        day: day,
        date: sprint.start_date + day.days,
        hours_remaining: ideal_hours.round(1)
      }
      
      # 벨로시티 기반 예측
      projected_hours = total_hours - (daily_velocity * day)
      projected_burndown << {
        day: day,
        date: sprint.start_date + day.days,
        hours_remaining: [projected_hours, 0].max.round(1)
      }
    end
    
    {
      ideal: ideal_burndown,
      projected: projected_burndown,
      completion_day: (total_hours / daily_velocity).ceil,
      will_complete: (total_hours / daily_velocity).ceil <= working_days
    }
  end
  
  def calculate_velocity
    # 최근 3개 스프린트 평균 벨로시티
    recent_sprints = sprint.service.sprints
                           .where(status: 'completed')
                           .where.not(id: sprint.id)
                           .order(end_date: :desc)
                           .limit(3)
    
    return 20.0 if recent_sprints.empty? # 기본값
    
    total_completed = recent_sprints.sum do |s|
      s.tasks.where(status: 'done').sum(:actual_hours) || 0
    end
    
    total_days = recent_sprints.sum do |s|
      business_days_between(s.start_date, s.end_date)
    end
    
    return 20.0 if total_days.zero?
    
    total_completed / total_days.to_f
  end
  
  def find_least_loaded_member
    # 간단한 라운드 로빈 방식으로 변경
    @member_index ||= 0
    return nil if team_members.empty?
    
    member = team_members[@member_index % team_members.length]
    @member_index += 1
    member
  end
  
  def business_days_between(start_date, end_date)
    return 0 if start_date.nil? || end_date.nil?
    return 0 if start_date > end_date
    
    (start_date..end_date).count { |date| !date.saturday? && !date.sunday? }
  end
  
  def sprint_data
    {
      start_date: sprint.start_date,
      end_date: sprint.end_date,
      tasks_count: sprint.tasks.count,
      team_size: team_members.count
    }
  end
end