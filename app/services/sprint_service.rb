# app/services/sprint_service.rb
class SprintService
  extend Broadcastable
  
  class << self
    def create_sprint(params)
      # PostgreSQL: Service 정의 확인
      service = Service.find(params[:service_id])
      
      # MongoDB: Sprint 실행 데이터 생성
      sprint = Mongodb::MongoSprint.create!(
        organization_id: service.organization_id,
        service_id: service.id,
        name: params[:name],
        goal: params[:goal],
        start_date: params[:start_date],
        end_date: params[:end_date],
        team_id: params[:team_id],
        milestone_id: params[:milestone_id],
        status: 'planning',
        sprint_number: next_sprint_number(service.id)
      )
      
      # 초기 메트릭 설정
      initialize_sprint_metrics(sprint)
      
      # 활동 로그
      log_activity('sprint_created', sprint)
      
      sprint
    end
    
    def add_task_to_sprint(sprint_id, task_params)
      sprint = Mongodb::MongoSprint.find(sprint_id)
      
      # 독립 Task 생성
      task = Mongodb::MongoTask.create!(
        organization_id: sprint.organization_id,
        service_id: sprint.service_id,
        sprint_id: sprint_id,
        milestone_id: sprint.milestone_id,
        title: task_params[:title],
        description: task_params[:description],
        assignee_id: task_params[:assignee_id],
        assignee_name: User.find_by(id: task_params[:assignee_id])&.name,
        story_points: task_params[:story_points],
        priority: task_params[:priority] || 'medium',
        status: 'todo',
        task_id: generate_task_id(sprint.service_id),
        task_type: task_params[:task_type] || 'feature'
      )
      
      # Sprint에 Task 추가
      sprint.add_task(task)
      
      # 실시간 알림
      broadcast_task_added(sprint, task)
      
      task
    end
    
    def update_task_status(task_id, new_status, user_id = nil)
      task = Mongodb::MongoTask.find(task_id)
      
      old_status = task.status
      task.update_status(new_status, user_id || Current.user&.id)
      
      # Sprint 메트릭 업데이트
      if task.sprint_id.present?
        sprint = Mongodb::MongoSprint.find(task.sprint_id)
        sprint.update_task_counts
        update_burndown_data(sprint)
      end
      
      # 활동 로그
      Mongodb::MongoActivity.log_task_activity(
        task, 
        'status_changed',
        { status: [old_status, new_status] }
      )
      
      # 실시간 브로드캐스트
      broadcast_task_update(task)
      
      task
    end
    
    def start_sprint(sprint_id)
      sprint = Mongodb::MongoSprint.find(sprint_id)
      
      return false unless sprint.status == 'planning'
      return false unless sprint.start_date <= Date.current
      
      sprint.status = 'active'
      sprint.save!
      
      # 번다운 데이터 초기화
      initialize_burndown_data(sprint)
      
      # 활동 로그
      log_activity('sprint_started', sprint)
      
      # 실시간 알림
      broadcast_sprint_status(sprint)
      
      true
    end
    
    def complete_sprint(sprint_id)
      sprint = Mongodb::MongoSprint.find(sprint_id)
      
      return false unless sprint.status == 'active'
      
      # Sprint 완료 처리
      sprint.status = 'completed'
      sprint.actual_velocity = calculate_actual_velocity(sprint)
      sprint.save!
      
      # 미완료 태스크 처리
      handle_incomplete_tasks(sprint)
      
      # 회고 데이터 준비
      prepare_retrospective_data(sprint)
      
      # 활동 로그
      log_activity('sprint_completed', sprint)
      
      # 실시간 알림
      broadcast_sprint_status(sprint)
      
      true
    end
    
    def update_daily_standup(sprint_id, standup_data)
      sprint = Mongodb::MongoSprint.find(sprint_id)
      
      today_standup = {
        date: Date.current,
        attendees: standup_data[:attendees] || [],
        updates: standup_data[:updates] || [],
        duration_minutes: standup_data[:duration] || 15
      }
      
      # 오늘 스탠드업 업데이트 또는 추가
      existing_index = sprint.daily_standups.find_index { |s| s[:date] == Date.current }
      
      if existing_index
        sprint.daily_standups[existing_index] = today_standup
      else
        sprint.daily_standups << today_standup
      end
      
      sprint.save!
      
      # 실시간 브로드캐스트
      broadcast_standup_update(sprint, today_standup)
      
      sprint
    end
    
    def get_burndown_data(sprint_id)
      sprint = Mongodb::MongoSprint.find(sprint_id)
      
      # 이상적인 번다운 라인
      ideal_line = sprint.burndown_ideal_line
      
      # 실제 번다운 데이터
      actual_data = calculate_actual_burndown(sprint)
      
      {
        sprint_id: sprint.id.to_s,
        sprint_name: sprint.name,
        ideal: ideal_line,
        actual: actual_data,
        remaining_days: (sprint.end_date - Date.current).to_i,
        health_score: sprint.calculate_health_score
      }
    end
    
    private
    
    def next_sprint_number(service_id)
      last_sprint = Mongodb::MongoSprint
        .where(service_id: service_id)
        .order_by(sprint_number: :desc)
        .first
      
      last_sprint ? last_sprint.sprint_number + 1 : 1
    end
    
    def generate_task_id(service_id)
      service = Service.find(service_id)
      prefix = service.task_prefix || "TASK"
      
      # 해당 서비스의 마지막 태스크 번호 찾기
      last_task = Mongodb::MongoTask
        .where(service_id: service_id)
        .where(task_id: /^#{prefix}-\d+$/)
        .order_by(created_at: :desc)
        .first
      
      if last_task && last_task.task_id.match(/^#{prefix}-(\d+)$/)
        next_number = $1.to_i + 1
      else
        next_number = 1
      end
      
      "#{prefix}-#{next_number}"
    end
    
    def initialize_sprint_metrics(sprint)
      # 번다운 데이터 초기화
      sprint.burndown_data = []
      sprint.health_score = 100
      sprint.risk_level = 'low'
      
      # 팀 용량 계산
      if sprint.team_id
        team = Team.find_by(id: sprint.team_id)
        if team
          sprint.team_capacity = calculate_team_capacity(team, sprint)
        end
      end
      
      sprint.save!
    end
    
    def initialize_burndown_data(sprint)
      total_points = sprint.committed_points || 0
      
      sprint.burndown_data = [{
        date: Date.current,
        ideal_remaining: total_points,
        actual_remaining: total_points,
        tasks_completed: 0,
        points_completed: 0
      }]
      
      sprint.save!
    end
    
    def update_burndown_data(sprint)
      tasks = Mongodb::MongoTask.in_sprint(sprint.id)
      
      today_data = {
        date: Date.current,
        actual_remaining: tasks.where(:status.ne => 'done').sum(:story_points) || 0,
        tasks_completed: tasks.where(status: 'done', completed_at: Date.current).count,
        points_completed: tasks.where(status: 'done', completed_at: Date.current).sum(:story_points) || 0
      }
      
      # 이상적인 번다운 계산
      if sprint.burndown_ideal_line.any?
        ideal_for_today = sprint.burndown_ideal_line.find { |d| d[:date] == Date.current }
        today_data[:ideal_remaining] = ideal_for_today[:ideal_remaining] if ideal_for_today
      end
      
      # 기존 데이터 업데이트 또는 추가
      existing = sprint.burndown_data.find { |d| d[:date] == Date.current }
      if existing
        existing.merge!(today_data)
      else
        sprint.burndown_data << today_data
      end
      
      sprint.save!
    end
    
    def calculate_actual_velocity(sprint)
      tasks = Mongodb::MongoTask.in_sprint(sprint.id)
      tasks.completed.sum(:story_points) || 0
    end
    
    def calculate_actual_burndown(sprint)
      tasks = Mongodb::MongoTask.in_sprint(sprint.id)
      burndown = []
      
      (sprint.start_date..Date.current).each do |date|
        completed_until = tasks.where(:completed_at.lte => date.end_of_day)
        remaining = sprint.committed_points - completed_until.sum(:story_points)
        
        burndown << {
          date: date,
          remaining: remaining,
          completed: completed_until.count
        }
      end
      
      burndown
    end
    
    def calculate_team_capacity(team, sprint)
      working_days = sprint.working_days || business_days_between(sprint.start_date, sprint.end_date)
      team_members = team.users.count
      hours_per_day = 8
      
      working_days * team_members * hours_per_day
    end
    
    def business_days_between(start_date, end_date)
      (start_date..end_date).select { |d| (1..5).include?(d.wday) }.count
    end
    
    def handle_incomplete_tasks(sprint)
      incomplete_tasks = Mongodb::MongoTask
        .in_sprint(sprint.id)
        .where(:status.ne => 'done')
      
      incomplete_tasks.each do |task|
        # 다음 스프린트로 이동하거나 백로그로 이동
        task.move_to_backlog
        
        # 활동 로그
        Mongodb::MongoActivity.log_task_activity(
          task,
          'moved_to_backlog',
          { reason: 'sprint_completed' }
        )
      end
      
      sprint.spillover_points = incomplete_tasks.sum(:story_points) || 0
      sprint.save!
    end
    
    def prepare_retrospective_data(sprint)
      tasks = Mongodb::MongoTask.in_sprint(sprint.id)
      
      sprint.retrospective = {
        date: Time.current,
        total_planned: sprint.committed_points,
        total_completed: sprint.actual_velocity,
        completion_rate: (sprint.actual_velocity.to_f / sprint.committed_points * 100).round(2),
        task_statistics: {
          total: tasks.count,
          completed: tasks.completed.count,
          incomplete: tasks.where(:status.ne => 'done').count
        }
      }
      
      sprint.save!
    end
    
    def log_activity(action, sprint)
      Mongodb::MongoActivity.log_sprint_activity(
        sprint,
        action,
        {
          sprint_number: sprint.sprint_number,
          status: sprint.status
        }
      )
    end
    
    # Broadcast methods are now included from Broadcastable module
  end
end