# app/models/mongodb/mongo_activity.rb
module Mongodb
  class MongoActivity
    include Mongoid::Document
    include Mongoid::Timestamps
    
    # MongoDB 컬렉션 이름 설정
    store_in collection: "activities"
    
    # ===== Context (PostgreSQL UUIDs) =====
    field :organization_id, type: String  # UUID from PostgreSQL
    field :actor_id, type: String         # UUID from PostgreSQL User
    field :actor_name, type: String
    field :actor_type, type: String, default: 'user' # user, system, integration
    
    # ===== Activity Info =====
    field :action, type: String # created, updated, completed, commented, etc.
    field :target_type, type: String # MongoTask, MongoSprint, Milestone
    field :target_id, type: String
    field :target_title, type: String
    
    # ===== Changes =====
    field :activity_changes, type: Hash
    # {
    #   status: ['todo', 'in_progress'],
    #   assignee: [nil, 5],
    #   priority: ['medium', 'high']
    # }
    
    field :activity_metadata, type: Hash
    # Additional context specific to action type
    
    # ===== Visibility =====
    field :visibility, type: String, default: 'team'
    field :team_id, type: String          # UUID from PostgreSQL Team
    field :mentioned_user_ids, type: Array, default: []  # Array of UUID strings
    
    # ===== Source =====
    field :source, type: String, default: 'web' # web, api, mobile, integration
    field :ip_address, type: String
    field :user_agent, type: String
    
    # ===== Indexes =====
    index({ organization_id: 1, created_at: -1 })
    index({ actor_id: 1, created_at: -1 })
    index({ target_type: 1, target_id: 1 })
    
    # TTL: 6개월 후 자동 삭제
    index({ created_at: 1 }, { expire_after_seconds: 15552000 })
    
    # ===== Validations =====
    validates :organization_id, presence: true
    validates :actor_id, presence: true
    validates :action, presence: true
    validates :target_type, presence: true
    validates :target_id, presence: true
    
    # ===== Scopes =====
    scope :recent, -> { order(created_at: :desc) }
    scope :by_actor, ->(actor_id) { where(actor_id: actor_id) }
    scope :by_target, ->(type, id) { where(target_type: type, target_id: id) }
    scope :by_organization, ->(org_id) { where(organization_id: org_id) }
    scope :today, -> { where(:created_at.gte => Date.current.beginning_of_day) }
    scope :this_week, -> { where(:created_at.gte => Date.current.beginning_of_week) }
    
    # ===== Class Methods =====
    class << self
      def log_activity(options = {})
        activity = new(
          organization_id: options[:organization_id],
          actor_id: options[:actor_id] || Current.user&.id,
          actor_name: options[:actor_name] || Current.user&.name,
          actor_type: options[:actor_type] || 'user',
          action: options[:action],
          target_type: options[:target_type],
          target_id: options[:target_id],
          target_title: options[:target_title],
          activity_changes: options[:changes] || {},
          activity_metadata: options[:metadata] || {},
          team_id: options[:team_id],
          source: options[:source] || 'web'
        )
        
        activity.save!
        
        # 실시간 브로드캐스트 (옵션)
        broadcast_activity(activity) if options[:broadcast]
        
        activity
      end
      
      def log_task_activity(task, action, changes = {})
        log_activity(
          organization_id: task.organization_id,
          action: action,
          target_type: 'MongoTask',
          target_id: task.id.to_s,
          target_title: task.title,
          changes: changes,
          team_id: task.team_id
        )
      end
      
      def log_sprint_activity(sprint, action, metadata = {})
        log_activity(
          organization_id: sprint.organization_id,
          action: action,
          target_type: 'MongoSprint',
          target_id: sprint.id.to_s,
          target_title: sprint.name,
          metadata: metadata,
          team_id: sprint.team_id
        )
      end
      
      private
      
      def broadcast_activity(activity)
        # Broadcast to organization channel
        ActionCable.server.broadcast(
          "activities_organization_#{activity.organization_id}",
          {
            action: 'new_activity',
            activity: activity.to_timeline_event
          }
        )
        
        # Broadcast to team channel if present
        if activity.team_id.present?
          ActionCable.server.broadcast(
            "activities_team_#{activity.team_id}",
            {
              action: 'new_activity',
              activity: activity.to_timeline_event
            }
          )
        end
        
        # Broadcast to mentioned users
        activity.mentioned_user_ids.each do |user_id|
          ActionCable.server.broadcast(
            "activities_user_#{user_id}",
            {
              action: 'mentioned_in_activity',
              activity: activity.to_timeline_event
            }
          )
        end
      end
    end
    
    # ===== Instance Methods =====
    def actor
      @actor ||= User.find_by(id: actor_id) if actor_id
    end
    
    def target
      @target ||= target_type.constantize.find(target_id)
    rescue
      nil
    end
    
    def organization
      @organization ||= Organization.find_by(id: organization_id)
    end
    
    def team
      @team ||= Team.find_by(id: team_id) if team_id
    end
    
    def humanized_action
      case action
      when 'created' then "created #{target_type.underscore.humanize.downcase}"
      when 'updated' then "updated #{target_type.underscore.humanize.downcase}"
      when 'completed' then "completed #{target_type.underscore.humanize.downcase}"
      when 'commented' then "commented on #{target_type.underscore.humanize.downcase}"
      when 'assigned' then "assigned #{target_type.underscore.humanize.downcase}"
      when 'moved' then "moved #{target_type.underscore.humanize.downcase}"
      when 'archived' then "archived #{target_type.underscore.humanize.downcase}"
      else action.humanize.downcase
      end
    end
    
    def description
      desc = "#{actor_name} #{humanized_action}"
      desc += " \"#{target_title}\"" if target_title.present?
      
      if activity_changes.any?
        change_descriptions = activity_changes.map do |field, values|
          from, to = values
          case field.to_s
          when 'status'
            "status from #{from} to #{to}"
          when 'assignee_id'
            if to
              assignee = User.find_by(id: to)
              "assigned to #{assignee&.name || 'Unknown'}"
            else
              "unassigned"
            end
          when 'priority'
            "priority from #{from} to #{to}"
          else
            "#{field.to_s.humanize.downcase} changed"
          end
        end
        
        desc += " (#{change_descriptions.join(', ')})"
      end
      
      desc
    end
    
    def to_timeline_event
      {
        id: id.to_s,
        timestamp: created_at,
        actor: {
          id: actor_id,
          name: actor_name,
          type: actor_type
        },
        action: action,
        target: {
          type: target_type,
          id: target_id,
          title: target_title
        },
        description: description,
        changes: activity_changes,
        metadata: activity_metadata
      }
    end
  end
end