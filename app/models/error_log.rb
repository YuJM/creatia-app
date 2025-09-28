class ErrorLog
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # 에러 정보
  field :error_class, type: String # 에러 클래스 이름
  field :error_message, type: String # 에러 메시지
  field :backtrace, type: Array # 스택 트레이스
  field :severity, type: String, default: 'error' # 심각도: debug, info, warn, error, fatal
  
  # 컨텍스트 정보
  field :controller, type: String
  field :action, type: String
  field :path, type: String
  field :method, type: String
  field :ip_address, type: String
  field :user_agent, type: String
  field :referrer, type: String
  
  # 사용자 정보
  field :user_id, type: Integer
  field :user_email, type: String
  field :organization_id, type: Integer
  field :organization_subdomain, type: String
  
  # 추가 데이터
  field :params, type: Hash # 요청 파라미터 (민감정보 제외)
  field :session_data, type: Hash # 세션 데이터 (민감정보 제외)
  field :environment, type: Hash # 환경 변수 (선택적)
  field :metadata, type: Hash # 추가 메타데이터
  
  # 처리 상태
  field :resolved, type: Boolean, default: false
  field :resolved_at, type: DateTime
  field :resolved_by_id, type: Integer
  field :resolution_notes, type: String
  field :occurrence_count, type: Integer, default: 1
  field :first_occurred_at, type: DateTime, default: -> { Time.current }
  field :last_occurred_at, type: DateTime, default: -> { Time.current }
  
  # 인덱스
  index({ created_at: -1 })
  index({ error_class: 1, created_at: -1 })
  index({ severity: 1, resolved: 1 })
  index({ organization_id: 1, created_at: -1 })
  index({ user_id: 1 })
  index({ resolved: 1, severity: 1 })
  index({ created_at: 1 }, expire_after_seconds: 180.days.to_i) # TTL 인덱스 - 180일 후 자동 삭제
  
  # 검증
  validates :error_class, presence: true
  validates :error_message, presence: true
  validates :severity, inclusion: { in: %w[debug info warn error fatal] }
  
  # 스코프
  scope :recent, -> { order(created_at: :desc) }
  scope :unresolved, -> { where(resolved: false) }
  scope :resolved, -> { where(resolved: true) }
  scope :critical, -> { where(severity: 'fatal') }
  scope :errors, -> { where(severity: 'error') }
  scope :warnings, -> { where(severity: 'warn') }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :today, -> { where(:created_at.gte => Date.current.beginning_of_day) }
  scope :this_week, -> { where(:created_at.gte => Date.current.beginning_of_week) }
  
  # 콜백
  before_create :set_first_occurred_at
  
  # 인스턴스 메소드
  def resolve!(user_id = nil, notes = nil)
    self.resolved = true
    self.resolved_at = Time.current
    self.resolved_by_id = user_id if user_id
    self.resolution_notes = notes if notes
    save!
  end
  
  def increment_occurrence!
    inc(occurrence_count: 1)
    set(last_occurred_at: Time.current)
  end
  
  # 클래스 메소드
  class << self
    def log_error(exception, context = {})
      # 동일한 에러가 최근에 발생했는지 확인
      existing = find_similar_error(exception, context)
      
      if existing
        existing.increment_occurrence!
        existing
      else
        create!(build_error_attributes(exception, context))
      end
    rescue => e
      Rails.logger.error "Failed to log error: #{e.message}"
      Rails.logger.error exception.message
      Rails.logger.error exception.backtrace.join("\n") if exception.backtrace
      nil
    end
    
    def find_similar_error(exception, context = {})
      where(
        error_class: exception.class.name,
        error_message: exception.message,
        controller: context[:controller],
        action: context[:action],
        resolved: false,
        :created_at.gte => 1.hour.ago
      ).first
    end
    
    def build_error_attributes(exception, context = {})
      {
        error_class: exception.class.name,
        error_message: exception.message,
        backtrace: exception.backtrace&.first(20), # 스택 트레이스 상위 20줄만
        severity: context[:severity] || 'error',
        controller: context[:controller],
        action: context[:action],
        path: context[:path],
        method: context[:method],
        ip_address: context[:ip_address],
        user_agent: context[:user_agent],
        referrer: context[:referrer],
        user_id: context[:user_id],
        user_email: context[:user_email],
        organization_id: context[:organization_id],
        organization_subdomain: context[:organization_subdomain],
        params: sanitize_params(context[:params]),
        session_data: sanitize_params(context[:session]),
        metadata: context[:metadata]
      }
    end
    
    def sanitize_params(params)
      return {} unless params
      
      # 민감한 정보 제거
      params = params.deep_dup if params.respond_to?(:deep_dup)
      sensitive_keys = %w[password password_confirmation token secret key credit_card]
      
      if params.is_a?(Hash)
        params.each do |key, value|
          if sensitive_keys.any? { |sk| key.to_s.downcase.include?(sk) }
            params[key] = '[FILTERED]'
          elsif value.is_a?(Hash)
            params[key] = sanitize_params(value)
          end
        end
      end
      
      params
    end
    
    # 통계 메소드
    def error_summary(organization_id = nil, days = 7)
      scope = organization_id ? by_organization(organization_id) : all
      scope.where(:created_at.gte => days.days.ago).group_by(&:severity).transform_values(&:count)
    end
    
    def top_errors(organization_id = nil, limit = 10)
      match = organization_id ? { organization_id: organization_id } : {}
      collection.aggregate([
        { "$match" => match.merge(resolved: false) },
        { "$group" => { 
          _id: { error_class: "$error_class", error_message: "$error_message" },
          count: { "$sum" => "$occurrence_count" },
          last_occurred: { "$max" => "$last_occurred_at" }
        }},
        { "$sort" => { count: -1 } },
        { "$limit" => limit }
      ])
    end
  end
  
  private
  
  def set_first_occurred_at
    self.first_occurred_at ||= Time.current
    self.last_occurred_at ||= Time.current
  end
end