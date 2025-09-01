# app/models/mongodb/mongo_comment.rb
module Mongodb
  class MongoComment
    include Mongoid::Document
    include Mongoid::Timestamps
    # include Mongoid::Tree # 중첩 댓글 지원 - 필요시 mongoid-tree gem 추가
    
    # MongoDB 컬렉션 이름 설정
    store_in collection: "comments"
    
    # ===== Polymorphic References =====
    field :commentable_type, type: String # 'MongoTask', 'MongoSprint', 'Milestone'
    field :commentable_id, type: String # MongoDB Document ID
    field :organization_id, type: Integer
    
    # ===== Author Info =====
    field :author_id, type: Integer
    field :author_name, type: String
    field :author_avatar, type: String
    field :author_role, type: String
    
    # ===== Comment Content =====
    field :content, type: String
    field :content_html, type: String # 렌더링된 HTML
    field :content_type, type: String, default: 'text' # text, code, image, file
    
    # ===== Rich Content =====
    field :code_snippet, type: Hash
    field :attachments, type: Array, default: []
    
    # ===== Mentions & References =====
    field :mentioned_user_ids, type: Array, default: []
    field :referenced_task_ids, type: Array, default: []
    field :referenced_comment_ids, type: Array, default: []
    
    # ===== Collaboration Features =====
    field :reactions, type: Hash, default: {}
    # { "👍": [1, 2, 3], "👎": [4], "🎉": [5, 6] }
    
    field :resolved, type: Boolean, default: false
    field :resolved_by_id, type: Integer
    field :resolved_at, type: Time
    
    # ===== Comment Type =====
    field :comment_type, type: String, default: 'general'
    # general, question, decision, action_item, status_update, review
    
    field :action_item, type: Hash
    
    # ===== Edit History =====
    field :edited, type: Boolean, default: false
    field :edit_history, type: Array, default: []
    
    # ===== Status & Visibility =====
    field :status, type: String, default: 'active' # active, deleted, hidden
    field :visibility, type: String, default: 'all' # all, team, mentioned_only
    field :pinned, type: Boolean, default: false
    field :system_generated, type: Boolean, default: false
    
    # ===== Activity Tracking =====
    field :read_by, type: Array, default: []
    
    # ===== Indexes =====
    index({ commentable_type: 1, commentable_id: 1, created_at: -1 })
    index({ author_id: 1 })
    index({ mentioned_user_ids: 1 })
    # index({ parent_id: 1 }) # Mongoid::Tree 사용시 활성화
    index({ pinned: 1, created_at: -1 })
    
    # TTL: 2년 후 자동 삭제 (pinned 제외)
    index({ created_at: 1 }, { 
      expire_after_seconds: 63072000,
      partial_filter_expression: { pinned: false }
    })
    
    # ===== Validations =====
    validates :commentable_type, presence: true
    validates :commentable_id, presence: true
    validates :author_id, presence: true
    validates :content, presence: true, length: { maximum: 10000 }
    validates :comment_type, inclusion: { 
      in: %w[general question decision action_item status_update review] 
    }
    
    # ===== Scopes =====
    scope :active, -> { where(status: 'active') }
    scope :resolved, -> { where(resolved: true) }
    scope :unresolved, -> { where(resolved: false) }
    scope :pinned, -> { where(pinned: true) }
    scope :action_items, -> { where(comment_type: 'action_item') }
    scope :decisions, -> { where(comment_type: 'decision') }
    scope :recent, -> { order(created_at: :desc) }
    scope :by_author, ->(author_id) { where(author_id: author_id) }
    
    # ===== Callbacks =====
    before_save :render_content_html
    after_create :notify_mentions
    after_create :update_commentable_count
    
    # ===== Instance Methods =====
    def author
      @author ||= User.find_by(id: author_id) if author_id
    end
    
    def commentable
      @commentable ||= commentable_type.constantize.find(commentable_id)
    rescue
      nil
    end
    
    def add_reaction(user_id, emoji)
      self.reactions[emoji] ||= []
      unless self.reactions[emoji].include?(user_id)
        self.reactions[emoji] << user_id
        save!
      end
    end
    
    def remove_reaction(user_id, emoji)
      return unless self.reactions[emoji]
      self.reactions[emoji].delete(user_id)
      self.reactions.delete(emoji) if self.reactions[emoji].empty?
      save!
    end
    
    def mark_as_resolved(user_id)
      self.resolved = true
      self.resolved_by_id = user_id
      self.resolved_at = Time.current
      save!
    end
    
    def mark_as_read(user_id)
      unless self.read_by.any? { |r| r[:user_id] == user_id }
        self.read_by << { user_id: user_id, read_at: Time.current }
        save!
      end
    end
    
    def edit_content(new_content, editor_id)
      self.edit_history << {
        previous_content: self.content,
        edited_by: editor_id,
        edited_at: Time.current
      }
      
      self.content = new_content
      self.edited = true
      save!
    end
    
    def soft_delete
      self.status = 'deleted'
      save!
    end
    
    def create_action_item(assignee_id, due_date = nil)
      self.comment_type = 'action_item'
      self.action_item = {
        assignee_id: assignee_id,
        due_date: due_date,
        completed: false,
        created_at: Time.current
      }
      save!
    end
    
    def complete_action_item(completer_id = nil)
      return unless comment_type == 'action_item' && action_item
      
      self.action_item[:completed] = true
      self.action_item[:completed_by] = completer_id
      self.action_item[:completed_at] = Time.current
      save!
    end
    
    private
    
    def render_content_html
      # 마크다운 렌더링, 멘션 링크 생성 등
      # TODO: 실제 마크다운 파서 구현
      self.content_html = content
      
      # 멘션 추출
      self.mentioned_user_ids = content.scan(/@user_(\d+)/).flatten.map(&:to_i).uniq
      
      # 태스크 참조 추출
      self.referenced_task_ids = content.scan(/\b([A-Z]+-\d+)\b/).flatten.uniq
    end
    
    def notify_mentions
      mentioned_user_ids.each do |user_id|
        # TODO: 알림 시스템 구현
        # NotificationService.notify_mention(user_id, self)
      end
    end
    
    def update_commentable_count
      if commentable && commentable.respond_to?(:comment_count)
        commentable.inc(comment_count: 1)
      end
    end
  end
end