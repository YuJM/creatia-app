class ApiRequestLog
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # 요청 정보
  field :endpoint, type: String # API 엔드포인트
  field :method, type: String # HTTP 메소드
  field :path, type: String # 전체 경로
  field :query_params, type: Hash # 쿼리 파라미터
  field :request_headers, type: Hash # 요청 헤더
  field :request_body, type: Hash # 요청 바디
  
  # 응답 정보
  field :status_code, type: Integer # HTTP 상태 코드
  field :response_headers, type: Hash # 응답 헤더
  field :response_body, type: Hash # 응답 바디 (선택적)
  field :response_time, type: Float # 응답 시간 (ms)
  
  # 클라이언트 정보
  field :ip_address, type: String
  field :user_agent, type: String
  field :api_version, type: String # API 버전
  field :client_id, type: String # OAuth 클라이언트 ID
  
  # 인증 정보
  field :user_id, type: Integer
  field :organization_id, type: Integer
  field :api_key, type: String # API 키 (해시화)
  field :auth_method, type: String # 인증 방법: api_key, oauth, jwt
  
  # 에러 정보
  field :error_message, type: String
  field :error_details, type: Hash
  
  # 추가 메타데이터
  field :metadata, type: Hash
  field :tags, type: Array, default: []
  
  # 인덱스
  index({ created_at: -1 })
  index({ endpoint: 1, created_at: -1 })
  index({ status_code: 1 })
  index({ user_id: 1, created_at: -1 })
  index({ organization_id: 1, created_at: -1 })
  index({ response_time: 1 })
  index({ created_at: 1 }, expire_after_seconds: 30.days.to_i) # TTL 인덱스 - 30일 후 자동 삭제
  
  # 검증
  validates :endpoint, presence: true
  validates :method, presence: true, inclusion: { in: %w[GET POST PUT PATCH DELETE HEAD OPTIONS] }
  validates :status_code, presence: true
  
  # 스코프
  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(:status_code.gte => 200, :status_code.lt => 300) }
  scope :client_errors, -> { where(:status_code.gte => 400, :status_code.lt => 500) }
  scope :server_errors, -> { where(:status_code.gte => 500) }
  scope :slow_requests, ->(threshold = 1000) { where(:response_time.gt => threshold) }
  scope :by_endpoint, ->(endpoint) { where(endpoint: endpoint) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :today, -> { where(:created_at.gte => Date.current.beginning_of_day) }
  scope :this_hour, -> { where(:created_at.gte => 1.hour.ago) }
  
  # 클래스 메소드
  class << self
    def log_request(params)
      # 민감한 정보 제거
      params = sanitize_request_data(params)
      create!(params)
    rescue => e
      Rails.logger.error "Failed to log API request: #{e.message}"
      nil
    end
    
    def sanitize_request_data(data)
      return data unless data.is_a?(Hash)
      
      sanitized = data.deep_dup
      
      # 헤더에서 민감한 정보 제거
      if sanitized[:request_headers]
        sanitized[:request_headers] = sanitize_headers(sanitized[:request_headers])
      end
      
      # 요청/응답 바디에서 민감한 정보 제거
      [:request_body, :response_body].each do |key|
        if sanitized[key]
          sanitized[key] = sanitize_params(sanitized[key])
        end
      end
      
      sanitized
    end
    
    def sanitize_headers(headers)
      return {} unless headers.is_a?(Hash)
      
      headers = headers.deep_dup
      sensitive_headers = %w[authorization x-api-key cookie set-cookie]
      
      headers.each do |key, value|
        if sensitive_headers.any? { |sh| key.to_s.downcase.include?(sh) }
          headers[key] = '[FILTERED]'
        end
      end
      
      headers
    end
    
    def sanitize_params(params)
      return {} unless params.is_a?(Hash)
      
      params = params.deep_dup
      sensitive_keys = %w[password password_confirmation token secret key credit_card ssn]
      
      params.each do |key, value|
        if sensitive_keys.any? { |sk| key.to_s.downcase.include?(sk) }
          params[key] = '[FILTERED]'
        elsif value.is_a?(Hash)
          params[key] = sanitize_params(value)
        elsif value.is_a?(Array)
          params[key] = value.map { |v| v.is_a?(Hash) ? sanitize_params(v) : v }
        end
      end
      
      params
    end
    
    # 통계 메소드
    def endpoint_stats(organization_id = nil, hours = 24)
      scope = organization_id ? by_organization(organization_id) : all
      match = { created_at: { "$gte" => hours.hours.ago } }
      match[:organization_id] = organization_id if organization_id
      
      collection.aggregate([
        { "$match" => match },
        { "$group" => {
          _id: "$endpoint",
          count: { "$sum" => 1 },
          avg_response_time: { "$avg" => "$response_time" },
          max_response_time: { "$max" => "$response_time" },
          min_response_time: { "$min" => "$response_time" },
          success_count: {
            "$sum" => {
              "$cond" => [
                { "$and" => [
                  { "$gte" => ["$status_code", 200] },
                  { "$lt" => ["$status_code", 300] }
                ]},
                1,
                0
              ]
            }
          }
        }},
        { "$sort" => { count: -1 } }
      ])
    end
    
    def response_time_percentiles(endpoint = nil, hours = 24)
      match = { created_at: { "$gte" => hours.hours.ago } }
      match[:endpoint] = endpoint if endpoint
      
      collection.aggregate([
        { "$match" => match },
        { "$group" => {
          _id: nil,
          p50: { "$percentile" => { input: "$response_time", p: [0.5] } },
          p75: { "$percentile" => { input: "$response_time", p: [0.75] } },
          p90: { "$percentile" => { input: "$response_time", p: [0.9] } },
          p95: { "$percentile" => { input: "$response_time", p: [0.95] } },
          p99: { "$percentile" => { input: "$response_time", p: [0.99] } }
        }}
      ]).first
    rescue => e
      # MongoDB 버전이 percentile을 지원하지 않는 경우 대체 로직
      times = where(match).pluck(:response_time).sort
      return {} if times.empty?
      
      {
        p50: times[(times.size * 0.5).to_i],
        p75: times[(times.size * 0.75).to_i],
        p90: times[(times.size * 0.9).to_i],
        p95: times[(times.size * 0.95).to_i],
        p99: times[(times.size * 0.99).to_i]
      }
    end
  end
end