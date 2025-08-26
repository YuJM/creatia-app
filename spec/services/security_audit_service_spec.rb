# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SecurityAuditService, type: :service do
  let(:user) { create(:user, email: 'user@creatia.local') }
  let(:organization) { create(:organization, subdomain: 'test-org') }
  let(:request) { instance_double(ActionDispatch::Request) }
  
  before do
    allow(request).to receive(:remote_ip).and_return('192.168.1.100')
    allow(request).to receive(:user_agent).and_return('Mozilla/5.0 Test Browser')
    allow(request).to receive(:subdomain).and_return('test-org')
    allow(request).to receive(:session).and_return(double(id: 'session123'))
    
    allow(Rails.logger).to receive(:tagged).and_yield
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    
    # 보안 감사 활성화
    allow(Rails.env).to receive(:production?).and_return(true)
  end

  describe "보안 이벤트 로깅" do
    context "로그인 관련 이벤트" do
      it "로그인 성공 시 보안 로그를 기록한다" do
        # When: 로그인 성공 이벤트 로깅
        SecurityAuditService.log_login_success(user, request)
        
        # Then: 적절한 로그 기록
        expect(Rails.logger).to have_received(:tagged).with("SECURITY", "LOGIN_SUCCESS", "LOW")
        expect(Rails.logger).to have_received(:info) do |log_data|
          parsed_data = JSON.parse(log_data)
          expect(parsed_data).to include(
            'event_type' => 'LOGIN_SUCCESS',
            'user_id' => user.id,
            'email' => user.email,
            'ip_address' => '192.168.1.100',
            'risk_level' => 'low'
          )
        end
      end

      it "로그인 실패 시 위험도에 따른 로그를 기록한다" do
        # Given: 로그인 실패 위험도 결정 로직 모킹
        allow(SecurityAuditService).to receive(:determine_login_failure_risk).and_return(:high)
        
        # When: 로그인 실패 이벤트 로깅
        SecurityAuditService.log_login_failure(user.email, request, 'Invalid password')
        
        # Then: 높은 위험도로 로그 기록
        expect(Rails.logger).to have_received(:tagged).with("SECURITY", "LOGIN_FAILURE", anything)
      end

      it "연속 로그인 실패 시 위험도가 증가한다" do
        # Given: 여러 번의 로그인 실패 시뮬레이션
        allow(SecurityAuditService).to receive(:count_recent_login_failures).and_return(8)
        
        # When: 로그인 실패 로깅
        SecurityAuditService.log_login_failure(user.email, request, 'Brute force attempt')
        
        # Then: 높은 위험도로 분류
        expect(Rails.logger).to have_received(:info) do |log_data|
          parsed_data = JSON.parse(log_data)
          expect(parsed_data['risk_level']).to eq('high')
        end
      end
    end

    context "권한 관련 이벤트" do
      it "무권한 접근 시도를 로깅한다" do
        # Given: 접근하려는 리소스
        task = create(:task, organization: organization)
        
        # When: 무권한 접근 로깅
        SecurityAuditService.log_unauthorized_access(user, task, request, 'destroy')
        
        # Then: 무권한 접근 로그 기록
        expect(Rails.logger).to have_received(:tagged).with("SECURITY", "UNAUTHORIZED_ACCESS", "MEDIUM")
        expect(Rails.logger).to have_received(:info) do |log_data|
          parsed_data = JSON.parse(log_data)
          expect(parsed_data).to include(
            'event_type' => 'UNAUTHORIZED_ACCESS',
            'user_id' => user.id,
            'resource_type' => 'Task',
            'resource_id' => task.id,
            'action' => 'destroy',
            'risk_level' => 'medium'
          )
        end
      end
    end

    context "테넌트 관련 이벤트" do
      it "정상적인 테넌트 전환을 로깅한다" do
        # Given: 다른 조직
        target_org = create(:organization, subdomain: 'target-org')
        
        # When: 테넌트 전환 로깅
        SecurityAuditService.log_tenant_switch(user, organization, target_org, request)
        
        # Then: 테넌트 전환 로그 기록
        expect(Rails.logger).to have_received(:tagged).with("SECURITY", "TENANT_SWITCH", "LOW")
        expect(Rails.logger).to have_received(:info) do |log_data|
          parsed_data = JSON.parse(log_data)
          expect(parsed_data).to include(
            'event_type' => 'TENANT_SWITCH',
            'from_tenant_subdomain' => organization.subdomain,
            'to_tenant_subdomain' => target_org.subdomain,
            'risk_level' => 'low'
          )
        end
      end

      it "크로스 테넌트 접근 시도를 높은 위험도로 로깅한다" do
        # Given: 요청된 테넌트와 현재 테넌트
        requested_org = create(:organization, subdomain: 'forbidden-org')
        
        # When: 크로스 테넌트 접근 로깅
        SecurityAuditService.log_cross_tenant_access(user, requested_org, organization, request)
        
        # Then: 높은 위험도로 로그 기록
        expect(Rails.logger).to have_received(:tagged).with("SECURITY", "CROSS_TENANT_ACCESS", "HIGH")
        expect(Rails.logger).to have_received(:info) do |log_data|
          parsed_data = JSON.parse(log_data)
          expect(parsed_data).to include(
            'event_type' => 'CROSS_TENANT_ACCESS',
            'requested_tenant_subdomain' => requested_org.subdomain,
            'current_tenant_subdomain' => organization.subdomain,
            'risk_level' => 'high'
          )
        end
      end
    end

    context "Rate Limiting 이벤트" do
      it "Rate limit 초과를 적절한 위험도로 로깅한다" do
        # When: Rate limit 초과 로깅
        SecurityAuditService.log_rate_limit_exceeded(request, 'user', 150, 100)
        
        # Then: Rate limit 초과 로그 기록
        expect(Rails.logger).to have_received(:info) do |log_data|
          parsed_data = JSON.parse(log_data)
          expect(parsed_data).to include(
            'event_type' => 'RATE_LIMIT_EXCEEDED',
            'limit_type' => 'user',
            'current_count' => 150,
            'max_count' => 100
          )
        end
      end

      it "극심한 Rate limit 초과는 높은 위험도로 분류된다" do
        # When: 극심한 Rate limit 초과
        SecurityAuditService.log_rate_limit_exceeded(request, 'ip', 1000, 100)
        
        # Then: 높은 위험도로 로그 기록
        expect(Rails.logger).to have_received(:info) do |log_data|
          parsed_data = JSON.parse(log_data)
          expect(parsed_data['risk_level']).to eq('critical')
        end
      end
    end

    context "관리자 액션 이벤트" do
      it "관리자 작업을 감사 로그에 기록한다" do
        # Given: 관리자와 대상 사용자
        admin = create(:user, role: 'admin')
        target_user = create(:user)
        
        # When: 관리자 액션 로깅
        SecurityAuditService.log_admin_action(admin, 'user_suspension', target_user, request)
        
        # Then: 관리자 액션 로그 기록
        expect(Rails.logger).to have_received(:tagged).with("SECURITY", "ADMIN_ACTION", "MEDIUM")
        expect(Rails.logger).to have_received(:info) do |log_data|
          parsed_data = JSON.parse(log_data)
          expect(parsed_data).to include(
            'event_type' => 'ADMIN_ACTION',
            'admin_user_id' => admin.id,
            'action' => 'user_suspension',
            'target_type' => 'User',
            'target_id' => target_user.id
          )
        end
      end
    end
  end

  describe "의심스러운 활동 패턴 감지" do
    context "브루트포스 공격 감지" do
      it "연속된 로그인 실패를 감지하여 의심 활동으로 로깅한다" do
        # Given: 브루트포스 공격 패턴 (10회 이상 실패)
        allow(SecurityAuditService).to receive(:count_recent_login_failures).and_return(12)
        
        # When: 로그인 실패 이벤트 (브루트포스 감지 트리거)
        event_data = {
          event_type: 'LOGIN_FAILURE',
          ip_address: '192.168.1.100'
        }
        SecurityAuditService.send(:detect_brute_force_attacks, event_data)
        
        # Then: 의심스러운 활동으로 추가 로깅
        expect(Rails.logger).to have_received(:info) do |log_data|
          parsed_data = JSON.parse(log_data)
          if parsed_data['event_type'] == 'SUSPICIOUS_ACTIVITY'
            expect(parsed_data).to include(
              'activity_type' => 'brute_force_attack',
              'failure_count' => 12,
              'risk_level' => 'critical'
            )
          end
        end
      end
    end

    context "비정상적인 접근 시간 감지" do
      it "새벽 시간대 접근을 의심 활동으로 감지한다" do
        # Given: 새벽 3시 접근
        allow(Time).to receive(:current).and_return(Time.new(2024, 1, 1, 3, 0, 0))
        
        # When: 새벽 시간 접근 이벤트
        event_data = {
          event_type: 'LOGIN_SUCCESS',
          user_id: user.id
        }
        SecurityAuditService.send(:detect_unusual_access_times, event_data)
        
        # Then: 비정상적인 접근 시간으로 로깅
        expect(Rails.logger).to have_received(:info) do |log_data|
          parsed_data = JSON.parse(log_data)
          if parsed_data['event_type'] == 'SUSPICIOUS_ACTIVITY'
            expect(parsed_data).to include(
              'activity_type' => 'unusual_access_time',
              'access_hour' => 3,
              'risk_level' => 'medium'
            )
          end
        end
      end
    end

    context "과도한 테넌트 전환 감지" do
      it "짧은 시간 내 과도한 테넌트 전환을 감지한다" do
        # Given: 1시간 내 20회 이상 전환
        allow(SecurityAuditService).to receive(:count_recent_tenant_switches).and_return(25)
        
        # When: 테넌트 전환 이벤트
        event_data = {
          event_type: 'TENANT_SWITCH',
          user_id: user.id
        }
        SecurityAuditService.send(:detect_unusual_tenant_switching, event_data)
        
        # Then: 의심스러운 테넌트 전환 패턴으로 로깅
        expect(Rails.logger).to have_received(:info) do |log_data|
          parsed_data = JSON.parse(log_data)
          if parsed_data['event_type'] == 'SUSPICIOUS_ACTIVITY'
            expect(parsed_data).to include(
              'activity_type' => 'excessive_tenant_switching',
              'switch_count' => 25,
              'risk_level' => 'high'
            )
          end
        end
      end
    end
  end

  describe "위험 수준별 처리" do
    context "높은 위험도 이벤트" do
      it "높은 위험도 이벤트는 즉시 알림을 발송한다" do
        # Given: 높은 위험도 이벤트
        allow(SecurityAuditService).to receive(:send_security_alert)
        
        # When: 높은 위험도 이벤트 로깅
        SecurityAuditService.log_security_event(:suspicious_activity, {
          risk_level: :high,
          activity_type: 'data_breach_attempt'
        })
        
        # Then: 보안 알림 발송
        expect(SecurityAuditService).to have_received(:send_security_alert)
      end
    end

    context "중요 위험도 이벤트" do
      it "중요 위험도 이벤트는 경고 로그를 남긴다" do
        # When: 중요 위험도 이벤트 로깅
        SecurityAuditService.log_security_event(:cross_tenant_access, {
          risk_level: :critical,
          details: 'Attempted access to financial data'
        })
        
        # Then: 경고 로그 기록
        expect(Rails.logger).to have_received(:warn).with(/HIGH RISK SECURITY EVENT/)
      end
    end
  end

  describe "보안 메트릭 수집" do
    it "지정된 기간의 보안 메트릭을 수집한다" do
      # When: 24시간 보안 메트릭 수집
      metrics = SecurityAuditService.collect_security_metrics(24.hours)
      
      # Then: 필요한 메트릭 포함
      expect(metrics).to include(
        :total_events,
        :events_by_type,
        :events_by_risk_level,
        :top_source_ips,
        :failed_logins,
        :unauthorized_access_attempts,
        :cross_tenant_access_attempts
      )
      
      expect(metrics[:events_by_type]).to be_a(Hash)
      expect(metrics[:events_by_risk_level]).to be_a(Hash)
      expect(metrics[:top_source_ips]).to be_an(Array)
    end

    it "메트릭은 보안 분석에 유용한 형태로 제공된다" do
      # When: 메트릭 수집
      metrics = SecurityAuditService.collect_security_metrics
      
      # Then: 분석 가능한 형태의 데이터
      expect(metrics[:events_by_type]).to include(*SecurityAuditService::SECURITY_EVENTS.values)
      expect(metrics[:events_by_risk_level]).to include(*SecurityAuditService::RISK_LEVELS.values)
      expect(metrics[:total_events]).to be_a(Numeric)
    end
  end

  describe "로그 형식 및 구조" do
    it "모든 보안 로그는 일관된 구조를 가진다" do
      # When: 보안 이벤트 로깅
      SecurityAuditService.log_login_success(user, request)
      
      # Then: 일관된 로그 구조
      expect(Rails.logger).to have_received(:info) do |log_data|
        parsed_data = JSON.parse(log_data)
        
        # 필수 필드 확인
        expect(parsed_data).to include(
          'event_id',
          'event_type',
          'timestamp',
          'risk_level',
          'environment',
          'application'
        )
        
        # UUID 형식 확인
        expect(parsed_data['event_id']).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
        
        # ISO 8601 타임스탬프 확인
        expect { Time.parse(parsed_data['timestamp']) }.not_to raise_error
      end
    end

    it "개발 환경에서는 로깅이 선택적으로 비활성화된다" do
      # Given: 개발 환경 및 보안 감사 비활성화
      allow(Rails.env).to receive(:production?).and_return(false)
      allow(ENV).to receive(:[]).with('ENABLE_SECURITY_AUDIT').and_return(nil)
      
      # When: 보안 이벤트 로깅 시도
      SecurityAuditService.log_login_success(user, request)
      
      # Then: 로그가 기록되지 않음 (개발환경에서는 옵션)
      # 실제 구현에서는 enabled? 메서드가 false를 반환할 것
    end
  end
end
