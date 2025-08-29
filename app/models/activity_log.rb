class ActivityLog
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # 기본 필드
  field :action, type: String # 액션 이름 (예: 'user_login', 'task_created')
  field :controller, type: String # 컨트롤러 이름
  field :method, type: String # HTTP 메소드
  field :path, type: String # 요청 경로
  field :ip_address, type: String # IP 주소
  field :user_agent, type: String # User Agent
  field :status, type: Integer # HTTP 응답 코드
  field :duration, type: Float # 처리 시간 (ms)
  
  # 사용자 정보
  field :user_id, type: Integer # PostgreSQL User ID
  field :user_email, type: String # 사용자 이메일 (빠른 검색용)
  field :organization_id, type: Integer # 조직 ID
  field :organization_subdomain, type: String # 조직 서브도메인
  
  # 추가 데이터
  field :params, type: Hash # 요청 파라미터 (민감정보 제외)
  field :metadata, type: Hash # 추가 메타데이터
  field :data_changes, type: Hash # 변경 사항 (update 액션시)
  
  # 인덱스
  index({ created_at: -1 })
  index({ user_id: 1, created_at: -1 })
  index({ organization_id: 1, created_at: -1 })
  index({ action: 1, created_at: -1 })
  index({ status: 1 })
  index({ created_at: 1 }, expire_after_seconds: 90.days.to_i) # TTL 인덱스 - 90일 후 자동 삭제
  
  # 스코프
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :by_action, ->(action) { where(action: action) }
  scope :successful, -> { where(:status.gte => 200, :status.lt => 300) }
  scope :failed, -> { where(:status.gte => 400) }
  scope :today, -> { where(:created_at.gte => Date.current.beginning_of_day) }
  scope :this_week, -> { where(:created_at.gte => Date.current.beginning_of_week) }
  scope :this_month, -> { where(:created_at.gte => Date.current.beginning_of_month) }
  
  # 클래스 메소드
  class << self
    def log_activity(params)
      create!(params)
    rescue => e
      Rails.logger.error "Failed to log activity: #{e.message}"
      nil
    end
    
    def cleanup_old_logs(days = 90)
      where(:created_at.lt => days.days.ago).delete_all
    end
    
    # 통계 메소드
    def daily_stats(organization_id = nil)
      scope = organization_id ? by_organization(organization_id) : all
      scope.today.group_by { |log| log.action }.transform_values(&:count)
    end
    
    def popular_actions(organization_id = nil, limit = 10)
      match = organization_id ? { organization_id: organization_id } : {}
      collection.aggregate([
        { "$match" => match.merge(created_at: { "$gte" => 7.days.ago }) },
        { "$group" => { _id: "$action", count: { "$sum" => 1 } } },
        { "$sort" => { count: -1 } },
        { "$limit" => limit }
      ])
    end
  end
end