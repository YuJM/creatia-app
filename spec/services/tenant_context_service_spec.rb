# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantContextService, type: :service do
  let(:user) { create(:user) }
  let(:organization) { create(:organization, subdomain: 'test-org', active: true) }
  let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'member', active: true) }
  
  let(:request) { instance_double(ActionDispatch::Request) }
  
  before do
    allow(DomainService).to receive(:base_domain).and_return('creatia.local')
  end

  describe "테넌트 컨텍스트 설정" do
    context "유효한 조직 서브도메인으로 요청" do
      before do
        allow(DomainService).to receive(:extract_subdomain).with(request).and_return('test-org')
      end

      it "조직이 존재하고 활성화되어 있으면 테넌트 컨텍스트를 설정한다" do
        # Given: 유효한 조직과 사용자
        service = TenantContextService.new(request, user)
        
        # When: 테넌트 컨텍스트 설정
        result = service.setup_tenant_context!
        
        # Then: 조직이 현재 테넌트로 설정됨
        expect(result).to eq(organization)
        expect(ActsAsTenant.current_tenant).to eq(organization)
        expect(service.tenant_set?).to be true
      end

      it "사용자가 조직 멤버가 아니면 접근을 거부한다" do
        # Given: 조직 멤버가 아닌 사용자
        non_member = create(:user)
        service = TenantContextService.new(request, non_member)
        
        # When: 테넌트 컨텍스트 설정 시도
        # Then: 접근 거부 예외 발생
        expect {
          service.setup_tenant_context!
        }.to raise_error(TenantContextService::AccessDenied, /접근할 권한이 없습니다/)
      end

      it "비활성화된 조직에는 접근할 수 없다" do
        # Given: 비활성화된 조직
        organization.update!(active: false)
        service = TenantContextService.new(request, user)
        
        # When: 테넌트 컨텍스트 설정 시도
        # Then: 유효하지 않은 테넌트 예외 발생
        expect {
          service.setup_tenant_context!
        }.to raise_error(TenantContextService::InvalidTenant, /비활성화된 조직/)
      end

      it "비활성화된 멤버십을 가진 사용자는 접근할 수 없다" do
        # Given: 비활성화된 멤버십
        membership.update!(active: false)
        service = TenantContextService.new(request, user)
        
        # When: 테넌트 컨텍스트 설정 시도
        # Then: 접근 거부 예외 발생
        expect {
          service.setup_tenant_context!
        }.to raise_error(TenantContextService::AccessDenied)
      end
    end

    context "존재하지 않는 조직 서브도메인으로 요청" do
      before do
        allow(DomainService).to receive(:extract_subdomain).with(request).and_return('nonexistent')
      end

      it "조직을 찾을 수 없으면 예외를 발생시킨다" do
        # Given: 존재하지 않는 조직 서브도메인
        service = TenantContextService.new(request, user)
        
        # When: 테넌트 컨텍스트 설정 시도
        # Then: 테넌트를 찾을 수 없음 예외 발생
        expect {
          service.setup_tenant_context!
        }.to raise_error(TenantContextService::TenantNotFound, /조직을 찾을 수 없습니다/)
      end
    end

    context "예약된 서브도메인으로 요청" do
      before do
        allow(DomainService).to receive(:extract_subdomain).with(request).and_return('auth')
      end

      it "예약된 서브도메인은 테넌트 설정을 건너뛴다" do
        # Given: 예약된 서브도메인 (auth)
        service = TenantContextService.new(request, user)
        
        # When: 테넌트 컨텍스트 설정
        result = service.setup_tenant_context!
        
        # Then: 테넌트 설정 건너뛰기
        expect(result).to be_nil
        expect(ActsAsTenant.current_tenant).to be_nil
      end
    end

    context "서브도메인 없이 요청" do
      before do
        allow(DomainService).to receive(:extract_subdomain).with(request).and_return(nil)
      end

      it "서브도메인이 없으면 테넌트 설정을 건너뛴다" do
        # Given: 서브도메인이 없는 요청
        service = TenantContextService.new(request, user)
        
        # When: 테넌트 컨텍스트 설정
        result = service.setup_tenant_context!
        
        # Then: 테넌트 설정 건너뛰기
        expect(result).to be_nil
        expect(ActsAsTenant.current_tenant).to be_nil
      end
    end
  end

  describe "테넌트 컨텍스트 관리" do
    let(:service) { TenantContextService.new(request, user) }

    before do
      allow(DomainService).to receive(:extract_subdomain).with(request).and_return('test-org')
      service.setup_tenant_context!
    end

    describe "#with_tenant" do
      it "임시로 다른 조직으로 컨텍스트를 전환한다" do
        # Given: 다른 조직
        other_org = create(:organization, subdomain: 'other-org')
        original_tenant = ActsAsTenant.current_tenant
        
        # When: 임시 테넌트 전환
        result = service.with_tenant(other_org) do
          ActsAsTenant.current_tenant
        end
        
        # Then: 블록 내에서는 다른 조직, 블록 후에는 원래 조직
        expect(result).to eq(other_org)
        expect(ActsAsTenant.current_tenant).to eq(original_tenant)
      end

      it "블록에서 예외가 발생해도 원래 테넌트로 복원한다" do
        # Given: 다른 조직
        other_org = create(:organization, subdomain: 'other-org')
        original_tenant = ActsAsTenant.current_tenant
        
        # When: 블록에서 예외 발생
        expect {
          service.with_tenant(other_org) do
            raise StandardError, "Test error"
          end
        }.to raise_error(StandardError, "Test error")
        
        # Then: 원래 테넌트로 복원
        expect(ActsAsTenant.current_tenant).to eq(original_tenant)
      end
    end

    describe "#clear_tenant_context!" do
      it "테넌트 컨텍스트를 클리어한다" do
        # Given: 설정된 테넌트 컨텍스트
        expect(service.tenant_set?).to be true
        
        # When: 컨텍스트 클리어
        service.clear_tenant_context!
        
        # Then: 테넌트 컨텍스트가 없어짐
        expect(service.tenant_set?).to be false
        expect(ActsAsTenant.current_tenant).to be_nil
      end
    end

    describe "사용자 권한 확인" do
      it "사용자가 현재 조직에 접근할 수 있는지 확인한다" do
        # Given: 조직 멤버인 사용자
        # When & Then: 접근 가능 확인
        expect(service.user_can_access?).to be true
        expect(service.user_role).to eq('member')
        expect(service.user_membership).to eq(membership)
      end

      it "조직 멤버가 아닌 사용자는 접근할 수 없다" do
        # Given: 조직 멤버가 아닌 사용자
        non_member = create(:user)
        non_member_service = TenantContextService.new(request, non_member)
        allow(DomainService).to receive(:extract_subdomain).with(request).and_return('test-org')
        
        # When: 테넌트 컨텍스트 설정 시도
        # Then: 접근 불가
        expect {
          non_member_service.setup_tenant_context!
        }.to raise_error(TenantContextService::AccessDenied)
      end
    end

    describe "접근 가능한 조직 목록" do
      it "사용자가 접근 가능한 모든 조직을 반환한다" do
        # Given: 사용자가 여러 조직의 멤버
        other_org = create(:organization, subdomain: 'other-org')
        create(:organization_membership, user: user, organization: other_org, role: 'admin')
        
        # When: 접근 가능한 조직 조회
        accessible_orgs = service.accessible_organizations
        
        # Then: 모든 조직 반환
        expect(accessible_orgs).to include(organization, other_org)
      end

      it "비활성화된 조직은 제외한다" do
        # Given: 비활성화된 조직
        inactive_org = create(:organization, subdomain: 'inactive', active: false)
        create(:organization_membership, user: user, organization: inactive_org, role: 'member')
        
        # When: 접근 가능한 조직 조회
        accessible_orgs = service.accessible_organizations
        
        # Then: 활성화된 조직만 반환
        expect(accessible_orgs).to include(organization)
        expect(accessible_orgs).not_to include(inactive_org)
      end
    end

    describe "컨텍스트 정보 제공" do
      it "현재 컨텍스트 정보를 해시로 반환한다" do
        # When: 컨텍스트 정보 조회
        context_info = service.context_info
        
        # Then: 필요한 정보 포함
        expect(context_info).to include(
          subdomain: 'test-org',
          organization: hash_including(
            id: organization.id,
            name: organization.name,
            subdomain: organization.subdomain
          ),
          user_role: 'member',
          tenant_set: true
        )
      end

      it "디버깅 정보를 제공한다" do
        # When: 디버깅 정보 조회
        debug_info = service.debug_info
        
        # Then: 디버깅에 유용한 정보 포함
        expect(debug_info).to include(
          extracted_subdomain: 'test-org',
          organization_found: true,
          organization_id: organization.id,
          user_present: true,
          user_can_access: true,
          user_role: 'member'
        )
      end
    end
  end

  describe "클래스 메서드" do
    describe ".setup_for_request!" do
      it "요청에 대한 테넌트 컨텍스트를 빠르게 설정한다" do
        # Given: 요청과 사용자
        allow(DomainService).to receive(:extract_subdomain).with(request).and_return('test-org')
        
        # When: 빠른 설정
        service = TenantContextService.setup_for_request!(request, user)
        
        # Then: 서비스 인스턴스 반환 및 컨텍스트 설정
        expect(service).to be_a(TenantContextService)
        expect(ActsAsTenant.current_tenant).to eq(organization)
      end
    end

    describe ".current_info" do
      it "현재 테넌트 정보를 반환한다" do
        # Given: 설정된 테넌트
        ActsAsTenant.current_tenant = organization
        
        # When: 현재 정보 조회
        info = TenantContextService.current_info
        
        # Then: 테넌트 정보 반환
        expect(info).to include(
          id: organization.id,
          name: organization.name,
          subdomain: organization.subdomain
        )
      end

      it "테넌트가 설정되지 않으면 nil을 반환한다" do
        # Given: 테넌트가 설정되지 않음
        ActsAsTenant.current_tenant = nil
        
        # When: 현재 정보 조회
        info = TenantContextService.current_info
        
        # Then: nil 반환
        expect(info).to be_nil
      end
    end

    describe ".clear!" do
      it "테넌트 컨텍스트를 클리어한다" do
        # Given: 설정된 테넌트
        ActsAsTenant.current_tenant = organization
        
        # When: 클리어
        TenantContextService.clear!
        
        # Then: 테넌트 컨텍스트 제거
        expect(ActsAsTenant.current_tenant).to be_nil
      end
    end
  end
end
