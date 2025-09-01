# app/models/mongodb/mongo_task.rb
module Mongodb
  class MongoTask
    include Mongoid::Document
    include Mongoid::Timestamps
    
    # MongoDB 컬렉션 이름 설정
    store_in collection: "tasks"
    
    # ===== Core References =====
    field :organization_id, type: Integer
    field :service_id, type: Integer
    field :sprint_id, type: String # MongoDB Sprint ID (optional - backlog tasks)
    field :milestone_id, type: String # MongoDB Milestone ID (optional)
    
    # ===== Task Identification =====
    field :task_id, type: String # 고유 ID (예: SHOP-123)
    field :external_id, type: String # Jira, GitHub Issue 등
    
    # ===== Task Core =====
    field :title, type: String
    field :description, type: String
    field :task_type, type: String, default: 'feature' # feature, bug, chore, spike, epic
    
    # ===== Assignment =====
    field :assignee_id, type: Integer
    field :assignee_name, type: String
    field :reviewer_id, type: Integer
    field :team_id, type: Integer
    field :created_by_id, type: Integer
    
    # ===== Status & Priority =====
    field :status, type: String, default: 'backlog' # backlog, todo, in_progress, review, done, archived
    field :priority, type: String, default: 'medium' # urgent, high, medium, low
    field :is_blocked, type: Boolean, default: false
    field :blocked_reason, type: String
    field :blocked_by_task_ids, type: Array, default: []
    
    # ===== Estimation & Tracking =====
    field :story_points, type: Float
    field :original_estimate_hours, type: Float
    field :time_spent_hours, type: Float, default: 0
    field :remaining_hours, type: Float
    field :business_value, type: Integer # 1-100
    
    # ===== Dates =====
    field :started_at, type: DateTime
    field :completed_at, type: DateTime
    field :archived_at, type: DateTime
    field :due_date, type: Date
    field :sprint_added_at, type: DateTime
    
    # ===== Progress Tracking =====
    field :subtasks, type: Array, default: []
    field :checklist_items, type: Array, default: []
    field :completion_percentage, type: Integer, default: 0
    
    # ===== Collaboration =====
    field :comment_count, type: Integer, default: 0
    field :attachment_count, type: Integer, default: 0
    field :watchers, type: Array, default: []
    field :participants, type: Array, default: []
    field :mentions, type: Array, default: []
    
    # ===== Development Tracking =====
    field :pull_requests, type: Array, default: []
    field :commits, type: Array, default: []
    field :branch_name, type: String
    field :deployment_status, type: String
    field :code_review_status, type: String
    
    # ===== Quality Metrics =====
    field :bug_count, type: Integer, default: 0
    field :reopen_count, type: Integer, default: 0
    field :review_cycles, type: Integer, default: 0
    field :test_coverage, type: Float
    field :acceptance_criteria, type: Array, default: []
    
    # ===== Activity History =====
    field :status_changes, type: Array, default: []
    field :sprint_history, type: Array, default: []
    
    # ===== Labels & Categorization =====
    field :labels, type: Array, default: []
    field :epic_id, type: String
    field :component, type: String
    field :feature_flag, type: String
    field :release_version, type: String
    
    # ===== Custom Fields =====
    field :custom_fields, type: Hash, default: {}
    field :metadata, type: Hash, default: {}
    
    # ===== Indexes =====
    index({ organization_id: 1, status: 1 })
    index({ sprint_id: 1, status: 1 })
    index({ assignee_id: 1, status: 1 })
    index({ status: 1, priority: 1 })
    index({ task_id: 1 }, { unique: true })
    index({ created_at: -1 })
    index({ due_date: 1 })
    index({ epic_id: 1 })
    
    # Partial index for active tasks
    index(
      { organization_id: 1, sprint_id: 1 },
      { 
        partial_filter_expression: { 
          status: { '$in': ['todo', 'in_progress', 'review'] }
        }
      }
    )
    
    # TTL: 완료 후 1년
    index(
      { archived_at: 1 }, 
      { 
        expire_after_seconds: 31536000,
        partial_filter_expression: { status: 'archived' }
      }
    )
    
    # ===== Validations =====
    validates :title, presence: true
    validates :task_id, presence: true, uniqueness: true
    validates :organization_id, presence: true
    validates :status, inclusion: { in: %w[backlog todo in_progress review done archived] }
    validates :priority, inclusion: { in: %w[urgent high medium low] }
    validates :task_type, inclusion: { in: %w[feature bug chore spike epic] }
    
    # ===== Scopes =====
    scope :active, -> { where(:status.in => ['todo', 'in_progress', 'review']) }
    scope :backlog, -> { where(status: 'backlog', sprint_id: nil) }
    scope :in_sprint, ->(sprint_id) { where(sprint_id: sprint_id) }
    scope :completed, -> { where(status: 'done') }
    scope :my_tasks, ->(user_id) { where(assignee_id: user_id) }
    scope :unassigned, -> { where(assignee_id: nil) }
    scope :blocked, -> { where(is_blocked: true) }
    scope :due_soon, -> { where(:due_date.lte => 3.days.from_now) }
    scope :overdue, -> { where(:due_date.lt => Date.current, :status.ne => 'done') }
    scope :high_priority, -> { where(:priority.in => ['urgent', 'high']) }
    
    # ===== Class Methods =====
    class << self
      def generate_task_id(service_id)
        service = Service.find(service_id)
        prefix = service.task_prefix || "TASK"
        
        # 해당 서비스의 마지막 태스크 번호 찾기
        last_task = where(service_id: service_id)
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
      
      def move_to_sprint(task_ids, sprint_id)
        tasks = where(:_id.in => task_ids)
        sprint = MongoSprint.find(sprint_id)
        
        tasks.each do |task|
          # Sprint 히스토리 업데이트
          if task.sprint_id.present?
            task.sprint_history << {
              sprint_id: task.sprint_id,
              removed_at: Time.current
            }
          end
          
          task.sprint_id = sprint_id
          task.sprint_added_at = Time.current
          task.sprint_history << {
            sprint_id: sprint_id,
            sprint_name: sprint.name,
            added_at: Time.current
          }
          task.save!
        end
      end
      
      def bulk_update_status(task_ids, new_status, user_id)
        tasks = where(:_id.in => task_ids)
        
        tasks.each do |task|
          task.update_status(new_status, user_id)
        end
      end
    end
    
    # ===== Instance Methods =====
    def move_to_backlog
      self.sprint_id = nil
      self.status = 'backlog'
      self.sprint_history << {
        sprint_id: self.sprint_id,
        removed_at: Time.current,
        reason: 'moved_to_backlog'
      } if self.sprint_id.present?
      save!
    end
    
    def archive!
      self.status = 'archived'
      self.archived_at = Time.current
      save!
    end
    
    def complete!
      self.status = 'done'
      self.completed_at = Time.current
      self.completion_percentage = 100
      
      # Sprint에서 완료 표시
      if sprint_id.present?
        current_sprint_history = sprint_history.last
        current_sprint_history[:completed_in_sprint] = true if current_sprint_history
      end
      
      save!
    end
    
    def update_status(new_status, user_id)
      old_status = self.status
      
      self.status_changes << {
        from: old_status,
        to: new_status,
        changed_by: user_id,
        changed_at: Time.current,
        sprint_id: self.sprint_id
      }
      
      self.status = new_status
      
      case new_status
      when 'in_progress'
        self.started_at ||= Time.current
      when 'done'
        self.completed_at = Time.current
        self.completion_percentage = 100
      when 'archived'
        self.archived_at = Time.current
      end
      
      save!
    end
    
    def add_comment(user_id, content)
      self.comment_count += 1
      self.participants << user_id unless self.participants.include?(user_id)
      save!
    end
    
    def add_subtask(title, assignee_id = nil)
      subtask = {
        id: BSON::ObjectId.new.to_s,
        title: title,
        completed: false,
        assignee_id: assignee_id,
        created_at: Time.current
      }
      
      self.subtasks << subtask
      update_completion_percentage
      save!
      
      subtask
    end
    
    def complete_subtask(subtask_id)
      subtask = self.subtasks.find { |st| st[:id] == subtask_id }
      return unless subtask
      
      subtask[:completed] = true
      subtask[:completed_at] = Time.current
      update_completion_percentage
      save!
    end
    
    def update_completion_percentage
      return if subtasks.empty? && checklist_items.empty?
      
      total_items = subtasks.size + checklist_items.size
      completed_items = subtasks.count { |st| st[:completed] } + 
                       checklist_items.count { |ci| ci[:completed] }
      
      self.completion_percentage = (completed_items.to_f / total_items * 100).round
    end
    
    def time_in_status
      return nil unless status_changes.any?
      
      last_change = status_changes.last
      Time.current - last_change[:changed_at]
    end
    
    def cycle_time
      return nil unless completed_at && created_at
      completed_at - created_at
    end
    
    def lead_time
      return nil unless completed_at && started_at
      completed_at - started_at
    end
    
    # PostgreSQL associations
    def assignee
      @assignee ||= User.find_by(id: assignee_id) if assignee_id
    end
    
    def reviewer
      @reviewer ||= User.find_by(id: reviewer_id) if reviewer_id
    end
    
    def created_by
      @created_by ||= User.find_by(id: created_by_id) if created_by_id
    end
    
    def organization
      @organization ||= Organization.find_by(id: organization_id) if organization_id
    end
    
    def service
      @service ||= Service.find_by(id: service_id) if service_id
    end
    
    def team
      @team ||= Team.find_by(id: team_id) if team_id
    end
  end
end