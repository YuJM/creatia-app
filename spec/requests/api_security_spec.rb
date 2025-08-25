# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "API 보안 및 멀티테넌트 격리", type: :request do
  let(:user) { create(:user) }
  let(:organization) { create(:organization, subdomain: 'api-test') }
  let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'member') }
  
  let(:other_org) { create(:organization, subdomain: 'other-org') }
  let!(:other_task) { create(:task, organization: other_org, title: 'Forbidden Task') }
  
  let(:auth_headers) { { 'Authorization' => "Bearer #{generate_jwt_token(user)}" } }

  before do
    allow(ActsAsTenant).to receive(:current_tenant).and_return(organization)
  end

  describe "테넌트 컨텍스트 API 보안" do
    context "올바른 테넌트 컨텍스트에서 API 호출" do
      it "사용자는 자신의 조직 데이터에 접근할 수 있다" do
        # Given: 현재 조직의 태스크
        task = create(:task, organization: organization, title: 'My Task')
        
        # When: 자신의 조직 태스크 조회
        get "/tasks/#{task.id}", headers: auth_headers.merge('Host' => 'api-test.creatia.local')
        
        # Then: 성공적으로 데이터 반환
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['title']).to eq('My Task')
      end

      it "조직별 태스크 목록 필터링이 정상 작동한다" do
        # Given: 여러 조직의 태스크들
        my_task = create(:task, organization: organization, title: 'My Task')
        create(:task, organization: other_org, title: 'Other Task')
        
        # When: 태스크 목록 조회
        get "/tasks", headers: auth_headers.merge('Host' => 'api-test.creatia.local')
        
        # Then: 자신의 조직 태스크만 반환
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        task_titles = json_response.map { |task| task['title'] }
        
        expect(task_titles).to include('My Task')
        expect(task_titles).not_to include('Other Task')
      end
    end

    context "크로스 테넌트 접근 시도" do
      it "다른 조직의 리소스에 직접 접근하면 404를 반환한다" do
        # Given: 다른 조직의 태스크 ID
        
        # When: 다른 조직 태스크에 접근 시도
        get "/tasks/#{other_task.id}", headers: auth_headers.merge('Host' => 'api-test.creatia.local')
        
        # Then: 찾을 수 없음 응답 (데이터 격리)
        expect(response).to have_http_status(:not_found)
      end

      it "잘못된 서브도메인 호스트로 요청하면 거부된다" do
        # Given: 권한 없는 서브도메인 호스트
        
        # When: 다른 조직 서브도메인으로 API 요청
        get "/tasks", headers: auth_headers.merge('Host' => 'other-org.creatia.local')
        
        # Then: 접근 거부
        expect(response).to have_http_status(:forbidden)
      end

      it "테넌트 컨텍스트 없이 API 호출하면 에러 응답" do
        # Given: 테넌트 컨텍스트가 설정되지 않은 상황
        allow(ActsAsTenant).to receive(:current_tenant).and_return(nil)
        
        # When: API 호출
        get "/tasks", headers: auth_headers
        
        # Then: Bad Request 응답
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('조직 컨텍스트가 필요합니다')
      end
    end
  end

  describe "Rate Limiting 보안" do
    let(:redis) { instance_double(Redis) }
    
    before do
      allow(Redis).to receive(:new).and_return(redis)
      allow(redis).to receive(:get).and_return('0')
      allow(redis).to receive(:multi).and_yield(redis)
      allow(redis).to receive(:incr)
      allow(redis).to receive(:expire)
    end

    context "정상적인 API 사용" do
      it "제한 범위 내의 요청은 정상 처리된다" do
        # Given: Rate limit 범위 내의 요청
        allow(redis).to receive(:get).and_return('50') # 시간당 제한 미만
        
        # When: API 요청
        get "/tasks", headers: auth_headers.merge('Host' => 'api-test.creatia.local')
        
        # Then: 정상 응답
        expect(response).to have_http_status(:ok)
      end
    end

    context "Rate Limit 초과" do
      it "IP별 제한 초과시 429 에러를 반환한다" do
        # Given: IP별 제한 초과
        allow(redis).to receive(:get).with(/rate_limit:ip:/).and_return('61') # 분당 60회 초과
        allow(redis).to receive(:ttl).and_return(30)
        
        # When: API 요청
        get "/tasks", headers: auth_headers.merge('Host' => 'api-test.creatia.local')
        
        # Then: Rate limit 에러
        expect(response).to have_http_status(:too_many_requests)
        expect(response.headers['Retry-After']).to eq('30')
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Rate limit exceeded')
        expect(json_response['limit_type']).to eq('ip')
      end

      it "사용자별 제한 초과시 429 에러를 반환한다" do
        # Given: 사용자별 제한 초과
        allow(redis).to receive(:get).with(/rate_limit:user:/).and_return('101') # 분당 100회 초과
        allow(redis).to receive(:ttl).and_return(45)
        
        # When: API 요청
        get "/tasks", headers: auth_headers.merge('Host' => 'api-test.creatia.local')
        
        # Then: Rate limit 에러
        expect(response).to have_http_status(:too_many_requests)
        expect(response.headers['Retry-After']).to eq('45')
        
        json_response = JSON.parse(response.body)
        expect(json_response['limit_type']).to eq('user')
      end

      it "조직별 제한 초과시 429 에러를 반환한다" do
        # Given: 조직별 제한 초과
        allow(redis).to receive(:get).with(/rate_limit:tenant:/).and_return('501') # 분당 500회 초과
        allow(redis).to receive(:ttl).and_return(60)
        
        # When: API 요청
        get "/tasks", headers: auth_headers.merge('Host' => 'api-test.creatia.local')
        
        # Then: Rate limit 에러
        expect(response).to have_http_status(:too_many_requests)
        json_response = JSON.parse(response.body)
        expect(json_response['limit_type']).to eq('tenant')
      end
    end

    context "Rate Limiting 우회 시도" do
      it "다른 IP로 전환해도 사용자별 제한은 적용된다" do
        # Given: 사용자별 제한 초과
        allow(redis).to receive(:get).with(/rate_limit:user:/).and_return('101')
        
        # When: 다른 IP에서 같은 사용자로 요청
        get "/tasks", headers: auth_headers.merge('Host' => 'api-test.creatia.local'), 
            env: { 'REMOTE_ADDR' => '192.168.1.100' }
        
        # Then: 여전히 Rate limit 적용
        expect(response).to have_http_status(:too_many_requests)
        json_response = JSON.parse(response.body)
        expect(json_response['limit_type']).to eq('user')
      end
    end
  end

  describe "보안 감사 로깅" do
    it "로그인 성공시 보안 로그가 기록된다" do
      # Given: 보안 감사 서비스 모킹
      allow(SecurityAuditService).to receive(:log_login_success)
      
      # When: 로그인 API 호출
      post "/users/sign_in", params: {
        user: { email: user.email, password: 'password123' }
      }, headers: { 'Host' => 'auth.creatia.local' }
      
      # Then: 보안 로그 기록
      expect(SecurityAuditService).to have_received(:log_login_success)
        .with(user, anything)
    end

    it "무권한 접근시 보안 로그가 기록된다" do
      # Given: 보안 감사 서비스 모킹
      allow(SecurityAuditService).to receive(:log_unauthorized_access)
      
      # When: 권한 없는 리소스에 접근
      delete "/tasks/#{other_task.id}", headers: auth_headers.merge('Host' => 'api-test.creatia.local')
      
      # Then: 무권한 접근 로그 기록
      expect(SecurityAuditService).to have_received(:log_unauthorized_access)
    end

    it "테넌트 전환시 보안 로그가 기록된다" do
      # Given: 다른 조직 멤버십도 보유
      other_membership = create(:organization_membership, user: user, organization: other_org, role: 'member')
      allow(SecurityAuditService).to receive(:log_tenant_switch)
      
      # When: 조직 전환 API 호출
      post "/tenant_switcher/switch", 
           params: { subdomain: 'other-org' },
           headers: auth_headers
      
      # Then: 테넌트 전환 로그 기록
      expect(SecurityAuditService).to have_received(:log_tenant_switch)
        .with(user, organization, other_org, anything)
    end
  end

  describe "세션 보안" do
    context "세션 하이재킹 방지" do
      it "IP 주소 변경시 세션을 무효화한다" do
        # Given: 기존 세션에서 다른 IP로 변경
        session = { user_id: user.id, last_ip: '192.168.1.1' }
        allow_any_instance_of(ActionDispatch::Request).to receive(:session).and_return(session)
        allow_any_instance_of(ActionDispatch::Request).to receive(:remote_ip).and_return('192.168.1.100')
        
        # When: API 요청
        get "/tasks", headers: auth_headers.merge('Host' => 'api-test.creatia.local')
        
        # Then: 세션 무효화 및 재로그인 요구
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "세션 타임아웃" do
      it "활동하지 않은 세션은 자동 만료된다" do
        # Given: 오래된 세션
        session = { 
          user_id: user.id, 
          last_activity_at: 9.hours.ago.iso8601 
        }
        allow_any_instance_of(ActionDispatch::Request).to receive(:session).and_return(session)
        
        # When: API 요청
        get "/tasks", headers: auth_headers.merge('Host' => 'api-test.creatia.local')
        
        # Then: 세션 만료 응답
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('세션이 만료되었습니다')
      end
    end
  end

  describe "입력 검증 보안" do
    context "서브도메인 검증" do
      it "유효하지 않은 서브도메인 형식을 거부한다" do
        # Given: SQL 인젝션 시도가 포함된 서브도메인
        malicious_subdomain = "test'; DROP TABLE organizations; --"
        
        # When: 악의적인 서브도메인으로 요청
        get "/tasks", headers: auth_headers.merge('Host' => "#{malicious_subdomain}.creatia.local")
        
        # Then: Bad Request 응답
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('유효하지 않은 서브도메인')
      end

      it "예약된 서브도메인은 특별 처리된다" do
        # Given: 예약된 서브도메인
        reserved_subdomains = %w[www auth api admin]
        
        reserved_subdomains.each do |subdomain|
          # When: 예약된 서브도메인으로 요청
          get "/tasks", headers: auth_headers.merge('Host' => "#{subdomain}.creatia.local")
          
          # Then: 테넌트 컨텍스트 설정 없이 처리
          # (예약된 서브도메인은 멀티테넌트 로직을 우회)
          expect(response).not_to have_http_status(:internal_server_error)
        end
      end
    end
  end

  private

  def generate_jwt_token(user)
    # 실제 구현에서는 JWT gem을 사용
    # 여기서는 테스트용 간단한 토큰
    "test_token_#{user.id}"
  end
end
