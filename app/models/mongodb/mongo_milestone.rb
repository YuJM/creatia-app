# app/models/mongodb/mongo_milestone.rb
module Mongodb
  class MongoMilestone
    include Mongoid::Document
    include Mongoid::Timestamps
    
    # MongoDB 컬렉션 이름 설정
    store_in collection: "milestones"
    
    # ===== Core References (PostgreSQL UUIDs) =====
    field :organization_id, type: String  # UUID from PostgreSQL
    field :service_id, type: String       # UUID from PostgreSQL
    
    # ===== Milestone Definition =====
    field :title, type: String
    field :description, type: String
    field :status, type: String, default: 'planning' # planning, active, completed, cancelled
    field :milestone_type, type: String, default: 'release' # release, feature, business
    
    # ===== Timeline =====
    field :planned_start, type: Date
    field :planned_end, type: Date
    field :actual_start, type: Date
    field :actual_end, type: Date
    
    # ===== Progress Tracking =====
    field :total_sprints, type: Integer, default: 0
    field :completed_sprints, type: Integer, default: 0
    field :total_tasks, type: Integer, default: 0
    field :completed_tasks, type: Integer, default: 0
    field :progress_percentage, type: Float, default: 0.0
    
    # ===== User Snapshots (Embedded) =====
    field :created_by_snapshot, type: Hash, default: {}
    # {
    #   user_id: "uuid",
    #   name: "John Doe",
    #   email: "john@example.com",
    #   avatar_url: "...",
    #   department: "Engineering",
    #   position: "Senior Developer",
    #   snapshot_at: DateTime
    # }
    
    field :owner_snapshot, type: Hash, default: {}
    
    field :stakeholder_snapshots, type: Array, default: []
    # [{
    #   user_id: "uuid",
    #   name: "Jane Doe",
    #   email: "jane@example.com",
    #   avatar_url: "...",
    #   role: "Product Manager",
    #   department: "Product",
    #   added_at: DateTime,
    #   snapshot_at: DateTime
    # }]
    
    field :team_lead_snapshots, type: Array, default: []
    # [{
    #   user_id: "uuid",
    #   name: "Team Lead",
    #   email: "lead@example.com",
    #   team_id: "uuid",
    #   team_name: "Backend Team",
    #   snapshot_at: DateTime
    # }]
    
    # ===== Objectives & Key Results =====
    field :objectives, type: Array, default: []
    # [{
    #   id: 'obj-1',
    #   title: 'Improve user engagement',
    #   description: String,
    #   owner_snapshot: { user_snapshot },
    #   key_results: [
    #     { 
    #       id: 'kr-1', 
    #       description: 'DAU 50% 증가', 
    #       target: 50000, 
    #       current: 35000, 
    #       unit: 'users',
    #       assigned_to_snapshot: { user_snapshot },
    #       updated_by_snapshot: { user_snapshot },
    #       last_updated: DateTime
    #     }
    #   ],
    #   created_at: DateTime
    # }]
    
    # ===== Risk & Dependencies =====
    field :risks, type: Array, default: []
    # [{
    #   id: "risk-1",
    #   title: String,
    #   description: String,
    #   severity: String, # low, medium, high, critical
    #   probability: String, # low, medium, high
    #   impact: String,
    #   mitigation_plan: String,
    #   raised_by_snapshot: { user_snapshot },
    #   owner_snapshot: { user_snapshot },
    #   status: String, # identified, mitigating, resolved, accepted
    #   created_at: DateTime,
    #   updated_at: DateTime
    # }]
    
    field :dependencies, type: Array, default: []
    # [{
    #   id: "dep-1",
    #   title: String,
    #   description: String,
    #   type: String, # internal, external, technical, business
    #   dependent_on: String, # team, service, milestone id
    #   owner_snapshot: { user_snapshot },
    #   status: String, # pending, resolved, blocked
    #   due_date: Date,
    #   created_at: DateTime
    # }]
    
    field :blockers, type: Array, default: []
    # [{
    #   id: "blocker-1",
    #   title: String,
    #   description: String,
    #   raised_by_snapshot: { user_snapshot },
    #   assigned_to_snapshot: { user_snapshot },
    #   severity: String,
    #   status: String, # open, in_progress, resolved
    #   resolution: String,
    #   created_at: DateTime,
    #   resolved_at: DateTime
    # }]
    
    # ===== Sprint References =====
    field :sprint_ids, type: Array, default: []
    
    # ===== Flexible Metadata =====
    field :custom_fields, type: Hash, default: {}
    field :integrations, type: Hash, default: {}
    # {
    #   jira: { project_id: 'PROJ-123', epic_id: 'EPIC-456' },
    #   github: { milestone_id: 789 },
    #   slack: { channel_id: 'C123456' }
    # }
    
    # ===== Change History =====
    field :change_log, type: Array, default: []
    # [{
    #   id: "change-1",
    #   type: String, # scope_change, date_change, owner_change, status_change
    #   description: String,
    #   old_value: Object,
    #   new_value: Object,
    #   changed_by_snapshot: { user_snapshot },
    #   reason: String,
    #   created_at: DateTime
    # }]
    
    # ===== Indexes =====
    index({ organization_id: 1, status: 1 })
    index({ service_id: 1 })
    index({ planned_end: 1 })
    index({ status: 1, actual_end: 1 })
    index({ "owner_snapshot.user_id": 1 })
    index({ "stakeholder_snapshots.user_id": 1 })
    index({ actual_end: 1 }, { expire_after_seconds: 63072000 }) # 2년 후 자동 삭제
    
    # ===== Validations =====
    validates :title, presence: true
    validates :organization_id, presence: true
    validates :status, inclusion: { in: %w[planning active completed cancelled] }
    validate :validate_dates
    
    # ===== Scopes =====
    scope :active, -> { where(status: 'active') }
    scope :completed, -> { where(status: 'completed') }
    scope :upcoming, -> { where(status: 'planning') }
    scope :at_risk, -> { where(:progress_percentage.lt => 30, :planned_end.lt => 30.days.from_now) }
    scope :by_owner, ->(user_id) { where("owner_snapshot.user_id" => user_id) }
    scope :by_stakeholder, ->(user_id) { where("stakeholder_snapshots.user_id" => user_id) }
    
    # ===== User Snapshot Methods =====
    def set_created_by(user)
      self.created_by_snapshot = create_user_snapshot(user)
    end
    
    def set_owner(user)
      old_owner = owner_snapshot
      self.owner_snapshot = create_user_snapshot(user)
      
      # Log the change
      if old_owner.present? && old_owner['user_id'] != user.id.to_s
        add_change_log('owner_change', 
          "Owner changed from #{old_owner['name']} to #{user.name}",
          old_owner,
          owner_snapshot,
          user
        )
      end
    end
    
    def add_stakeholder(user, role: nil)
      snapshot = create_user_snapshot(user).merge(
        role: role || user.role,
        added_at: DateTime.current
      )
      
      # 중복 방지
      self.stakeholder_snapshots.reject! { |s| s['user_id'] == user.id.to_s }
      self.stakeholder_snapshots << snapshot
    end
    
    def remove_stakeholder(user_id)
      self.stakeholder_snapshots.reject! { |s| s['user_id'] == user_id.to_s }
    end
    
    def add_team_lead(user, team)
      snapshot = create_user_snapshot(user).merge(
        team_id: team.id.to_s,
        team_name: team.name
      )
      
      # 중복 방지
      self.team_lead_snapshots.reject! { |t| t['user_id'] == user.id.to_s }
      self.team_lead_snapshots << snapshot
    end
    
    # ===== Objectives & Key Results Methods =====
    def add_objective(title, description, owner:, key_results: [])
      objective = {
        id: "obj-#{SecureRandom.hex(8)}",
        title: title,
        description: description,
        owner_snapshot: create_user_snapshot(owner),
        key_results: key_results.map { |kr| format_key_result(kr) },
        created_at: DateTime.current
      }
      
      self.objectives << objective
      objective
    end
    
    def update_key_result(objective_id, key_result_id, current_value, updated_by:)
      objective = objectives.find { |o| o['id'] == objective_id }
      return unless objective
      
      kr = objective['key_results'].find { |k| k['id'] == key_result_id }
      return unless kr
      
      kr['current'] = current_value
      kr['updated_by_snapshot'] = create_user_snapshot(updated_by)
      kr['last_updated'] = DateTime.current
    end
    
    # ===== Risk Management Methods =====
    def add_risk(title, description, severity:, probability:, raised_by:, owner: nil)
      risk = {
        id: "risk-#{SecureRandom.hex(8)}",
        title: title,
        description: description,
        severity: severity,
        probability: probability,
        impact: calculate_risk_impact(severity, probability),
        mitigation_plan: nil,
        raised_by_snapshot: create_user_snapshot(raised_by),
        owner_snapshot: owner ? create_user_snapshot(owner) : nil,
        status: 'identified',
        created_at: DateTime.current,
        updated_at: DateTime.current
      }
      
      self.risks << risk
      risk
    end
    
    def update_risk_mitigation(risk_id, mitigation_plan, owner:)
      risk = risks.find { |r| r['id'] == risk_id }
      return unless risk
      
      risk['mitigation_plan'] = mitigation_plan
      risk['owner_snapshot'] = create_user_snapshot(owner)
      risk['status'] = 'mitigating'
      risk['updated_at'] = DateTime.current
    end
    
    # ===== Dependency Management Methods =====
    def add_dependency(title, description, type:, dependent_on:, owner:, due_date: nil)
      dependency = {
        id: "dep-#{SecureRandom.hex(8)}",
        title: title,
        description: description,
        type: type,
        dependent_on: dependent_on,
        owner_snapshot: create_user_snapshot(owner),
        status: 'pending',
        due_date: due_date,
        created_at: DateTime.current
      }
      
      self.dependencies << dependency
      dependency
    end
    
    # ===== Blocker Management Methods =====
    def add_blocker(title, description, raised_by:, severity: 'high')
      blocker = {
        id: "blocker-#{SecureRandom.hex(8)}",
        title: title,
        description: description,
        raised_by_snapshot: create_user_snapshot(raised_by),
        assigned_to_snapshot: nil,
        severity: severity,
        status: 'open',
        resolution: nil,
        created_at: DateTime.current,
        resolved_at: nil
      }
      
      self.blockers << blocker
      blocker
    end
    
    def assign_blocker(blocker_id, assignee:)
      blocker = blockers.find { |b| b['id'] == blocker_id }
      return unless blocker
      
      blocker['assigned_to_snapshot'] = create_user_snapshot(assignee)
      blocker['status'] = 'in_progress'
    end
    
    def resolve_blocker(blocker_id, resolution)
      blocker = blockers.find { |b| b['id'] == blocker_id }
      return unless blocker
      
      blocker['resolution'] = resolution
      blocker['status'] = 'resolved'
      blocker['resolved_at'] = DateTime.current
    end
    
    # ===== Change Log Methods =====
    def add_change_log(type, description, old_value, new_value, changed_by, reason: nil)
      change = {
        id: "change-#{SecureRandom.hex(8)}",
        type: type,
        description: description,
        old_value: old_value,
        new_value: new_value,
        changed_by_snapshot: create_user_snapshot(changed_by),
        reason: reason,
        created_at: DateTime.current
      }
      
      self.change_log << change
    end
    
    # ===== Instance Methods =====
    def update_progress
      return if total_tasks.zero?
      
      self.progress_percentage = (completed_tasks.to_f / total_tasks * 100).round(2)
      save!
    end
    
    def days_remaining
      return nil unless planned_end
      (planned_end - Date.current).to_i
    end
    
    def is_overdue?
      planned_end && planned_end < Date.current && status != 'completed'
    end
    
    def health_status
      # 복잡한 건강 상태 계산
      score = 100
      
      # 진행률 확인
      if progress_percentage < expected_progress_percentage
        score -= 30
      end
      
      # 고위험 리스크 확인
      high_risks = risks.select { |r| r['severity'] == 'high' || r['severity'] == 'critical' }
      score -= high_risks.size * 10
      
      # 미해결 차단 사항 확인
      open_blockers = blockers.select { |b| b['status'] != 'resolved' }
      score -= open_blockers.size * 15
      
      # 미해결 의존성 확인
      pending_deps = dependencies.select { |d| d['status'] == 'pending' && d['due_date'] && d['due_date'] < Date.current }
      score -= pending_deps.size * 10
      
      case score
      when 80..100 then 'on_track'
      when 50..79 then 'at_risk'
      else 'critical'
      end
    end
    
    def expected_progress_percentage
      return 0 unless planned_start && planned_end
      return 100 if Date.current >= planned_end
      return 0 if Date.current <= planned_start
      
      total_days = (planned_end - planned_start).to_i
      elapsed_days = (Date.current - planned_start).to_i
      
      (elapsed_days.to_f / total_days * 100).round(2)
    end
    
    private
    
    def create_user_snapshot(user)
      return {} unless user
      
      {
        user_id: user.id.to_s,
        name: user.name,
        email: user.email,
        avatar_url: user.respond_to?(:avatar_url) ? user.avatar_url : nil,
        department: user.respond_to?(:department) ? user.department : nil,
        position: user.respond_to?(:position) ? user.position : nil,
        snapshot_at: DateTime.current
      }
    end
    
    def format_key_result(kr_data)
      {
        id: kr_data[:id] || "kr-#{SecureRandom.hex(8)}",
        description: kr_data[:description],
        target: kr_data[:target],
        current: kr_data[:current] || 0,
        unit: kr_data[:unit],
        assigned_to_snapshot: kr_data[:assigned_to] ? create_user_snapshot(kr_data[:assigned_to]) : nil,
        updated_by_snapshot: nil,
        last_updated: DateTime.current
      }
    end
    
    def calculate_risk_impact(severity, probability)
      severity_score = { 'low' => 1, 'medium' => 2, 'high' => 3, 'critical' => 4 }[severity] || 1
      probability_score = { 'low' => 1, 'medium' => 2, 'high' => 3 }[probability] || 1
      
      impact_score = severity_score * probability_score
      
      case impact_score
      when 1..3 then 'low'
      when 4..6 then 'medium'
      when 7..9 then 'high'
      else 'critical'
      end
    end
    
    def validate_dates
      if planned_start && planned_end
        errors.add(:planned_end, 'must be after planned start') if planned_end <= planned_start
      end
      
      if actual_start && actual_end
        errors.add(:actual_end, 'must be after actual start') if actual_end <= actual_start
      end
    end
  end
end