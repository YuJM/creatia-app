# app/models/mongodb/mongo_sprint.rb
module Mongodb
  class MongoSprint
    include Mongoid::Document
    include Mongoid::Timestamps
    
    # MongoDB 컬렉션 이름 설정
    store_in collection: "sprints"
    
    # ===== Core References =====
    field :organization_id, type: Integer
    field :service_id, type: Integer
    field :team_id, type: Integer
    field :milestone_id, type: String # MongoDB Milestone ID
    
    # ===== Sprint Definition =====
    field :name, type: String
    field :goal, type: String
    field :sprint_number, type: Integer
    field :status, type: String, default: 'planning' # planning, active, completed, cancelled
    
    # ===== Timeline =====
    field :start_date, type: Date
    field :end_date, type: Date
    field :working_days, type: Integer
    
    # ===== Capacity & Velocity =====
    field :team_capacity, type: Float # 총 가용 시간
    field :planned_velocity, type: Float # 계획 속도
    field :actual_velocity, type: Float # 실제 완료 포인트
    field :carry_over_velocity, type: Float # 이월된 포인트
    
    # ===== Sprint Planning =====
    field :committed_points, type: Float
    field :stretch_points, type: Float
    field :completed_points, type: Float
    field :spillover_points, type: Float
    
    # ===== Daily Tracking =====
    field :daily_standups, type: Array, default: []
    field :burndown_data, type: Array, default: []
    
    # ===== Sprint Ceremonies =====
    field :planning_session, type: Hash, default: {}
    field :review_session, type: Hash, default: {}
    field :retrospective, type: Hash, default: {}
    
    # ===== Task Management =====
    field :task_ids, type: Array, default: []
    field :total_tasks, type: Integer, default: 0
    field :completed_tasks, type: Integer, default: 0
    field :active_tasks, type: Integer, default: 0
    
    # ===== Health & Risk =====
    field :health_score, type: Float, default: 100.0
    field :risk_level, type: String, default: 'low'
    field :blockers, type: Array, default: []
    field :scope_changes, type: Array, default: []
    
    # ===== Team Dynamics =====
    field :team_members, type: Array, default: []
    
    # ===== Integrations =====
    field :external_links, type: Hash, default: {}
    
    # ===== Indexes =====
    index({ organization_id: 1, status: 1 })
    index({ service_id: 1, sprint_number: 1 })
    index({ team_id: 1, start_date: -1 })
    index({ status: 1, end_date: 1 })
    index({ end_date: 1 }, { expire_after_seconds: 31536000 }) # 1년 후 자동 삭제
    
    # ===== Validations =====
    validates :name, presence: true
    validates :organization_id, presence: true
    validates :start_date, presence: true
    validates :end_date, presence: true
    validates :status, inclusion: { in: %w[planning active completed cancelled] }
    validate :end_date_after_start_date
    
    # ===== Scopes =====
    scope :active, -> { where(status: 'active') }
    scope :completed, -> { where(status: 'completed') }
    scope :current, -> { where(status: 'active', :start_date.lte => Date.current, :end_date.gte => Date.current) }
    
    # ===== Instance Methods =====
    def tasks
      return @tasks if @tasks
      @tasks = task_ids.any? ? MongoTask.where(:_id.in => task_ids) : MongoTask.none
    end
    
    def add_task(task)
      task.sprint_id = self.id.to_s
      task.sprint_added_at = Time.current
      task.save!
      
      self.task_ids << task.id.to_s
      self.total_tasks += 1
      self.active_tasks += 1 if task.status.in?(['todo', 'in_progress', 'review'])
      self.save!
    end
    
    def remove_task(task)
      task.move_to_backlog
      
      self.task_ids.delete(task.id.to_s)
      self.total_tasks -= 1
      self.active_tasks -= 1 if task.status.in?(['todo', 'in_progress', 'review'])
      self.completed_tasks -= 1 if task.status == 'done'
      self.save!
    end
    
    def update_task_counts
      tasks_collection = MongoTask.where(:_id.in => task_ids)
      self.total_tasks = tasks_collection.count
      self.completed_tasks = tasks_collection.where(status: 'done').count
      self.active_tasks = tasks_collection.where(:status.in => ['todo', 'in_progress', 'review']).count
      self.save!
    end
    
    def calculate_health_score
      score = 100.0
      
      # Factor 1: Progress vs Time elapsed
      if start_date && end_date && Date.current.between?(start_date, end_date)
        time_elapsed_percent = ((Date.current - start_date).to_f / (end_date - start_date + 1) * 100).round
        progress_percent = completed_tasks.to_f / total_tasks * 100 rescue 0
        
        progress_delta = progress_percent - time_elapsed_percent
        score -= [progress_delta.abs, 30].min if progress_delta < 0
      end
      
      # Factor 2: Blockers
      score -= blockers.size * 5
      
      # Factor 3: Scope changes
      score -= scope_changes.size * 3
      
      self.health_score = [score, 0].max
      self.risk_level = case health_score
                        when 80..100 then 'low'
                        when 50..79 then 'medium'
                        else 'high'
                        end
      
      health_score
    end
    
    private
    
    def end_date_after_start_date
      return unless start_date && end_date
      errors.add(:end_date, 'must be after start date') if end_date <= start_date
    end
  end
end