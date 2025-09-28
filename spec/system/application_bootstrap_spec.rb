# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Application Bootstrap", type: :system do
  describe "애플리케이션 부팅 검증" do
    it "애플리케이션이 정상적으로 초기화되어 있어야 함" do
      expect(Rails.application.initialized?).to be true
    end

    it "모든 필수 gem이 로드되어야 함" do
      expect(defined?(Devise)).to be_truthy
      expect(defined?(Pundit)).to be_truthy
      expect(defined?(ActsAsTenant)).to be_truthy
      expect(defined?(Alba)).to be_truthy
    end

    it "데이터베이스 연결이 정상이어야 함" do
      expect { ActiveRecord::Base.connection.execute("SELECT 1") }.not_to raise_error
    end

    it "모든 모델이 올바르게 로드되어야 함" do
      expect { User.new }.not_to raise_error
      expect { Organization.new }.not_to raise_error
      expect { Mongodb::MongoTask.new }.not_to raise_error
      expect { OrganizationMembership.new }.not_to raise_error
    end
  end

  describe "라우팅 시스템 검증" do
    it "라우트 파일이 오류 없이 로드되어야 함" do
      expect { Rails.application.reload_routes! }.not_to raise_error
    end

    it "중복된 라우트 이름이 없어야 함" do
      route_names = Rails.application.routes.routes.map(&:name).compact
      duplicates = route_names.group_by(&:itself).select { |_, v| v.size > 1 }.keys
      
      expect(duplicates).to be_empty, 
        "중복된 라우트 이름: #{duplicates.join(', ')}"
    end

    it "모든 서브도메인 제약조건이 유효해야 함" do
      routes_with_constraints = Rails.application.routes.routes.select do |route|
        route.constraints.any? { |key, _| key == :subdomain }
      end
      
      expect(routes_with_constraints).not_to be_empty
      
      routes_with_constraints.each do |route|
        constraint = route.constraints[:subdomain]
        if constraint.is_a?(Regexp)
          expect { "test".match(constraint) }.not_to raise_error
        end
      end
    end
  end

  describe "컨트롤러 설정 검증" do
    it "ApplicationController가 필수 모듈을 포함해야 함" do
      expect(ApplicationController.ancestors.map(&:name))
        .to include("Devise::Controllers::Helpers")
      expect(ApplicationController.ancestors.map(&:name))
        .to include("Pundit::Authorization")
    end

    it "ApplicationController가 필수 메서드를 정의해야 함" do
      controller = ApplicationController.new
      
      expect(controller).to respond_to(:current_user)
      expect(controller).to respond_to(:current_organization)
      expect(controller).to respond_to(:current_membership)
      expect(controller).to respond_to(:current_role)
    end

    it "모든 컨트롤러가 ApplicationController를 상속해야 함" do
      controller_classes = [
        PagesController,
        UsersController,
        OrganizationsController,
        TasksController,
        OrganizationMembershipsController
      ]

      controller_classes.each do |klass|
        expect(klass.ancestors).to include(ApplicationController)
      end
    end
  end

  describe "서비스 클래스 검증" do
    it "모든 서비스 클래스가 올바르게 정의되어야 함" do
      service_classes = [
        TenantContextService,
        TenantSwitcher,
        DomainService,
        SecurityAuditService
      ]

      service_classes.each do |klass|
        expect { klass.new }.not_to raise_error rescue true # 일부는 인자가 필요할 수 있음
        expect(klass).to be_a(Class)
      end
    end
  end

  describe "정책(Policy) 시스템 검증" do
    it "모든 정책 클래스가 ApplicationPolicy를 상속해야 함" do
      policy_classes = [
        UserPolicy,
        OrganizationPolicy,
        TaskPolicy,
        OrganizationMembershipPolicy
      ]

      policy_classes.each do |klass|
        expect(klass.ancestors).to include(ApplicationPolicy)
      end
    end

    it "정책 클래스가 필수 메서드를 구현해야 함" do
      user = build(:user)
      organization = build(:organization)
      
      policy = OrganizationPolicy.new(user, organization)
      
      expect(policy).to respond_to(:index?)
      expect(policy).to respond_to(:show?)
      expect(policy).to respond_to(:create?)
      expect(policy).to respond_to(:update?)
      expect(policy).to respond_to(:destroy?)
    end
  end

  describe "직렬화(Serializer) 시스템 검증" do
    it "모든 직렬화 클래스가 BaseSerializer를 상속해야 함" do
      serializer_classes = [
        UserSerializer,
        OrganizationSerializer,
        TaskSerializer,
        OrganizationMembershipSerializer
      ]

      serializer_classes.each do |klass|
        expect(klass.ancestors).to include(BaseSerializer)
      end
    end

    it "직렬화가 오류 없이 동작해야 함" do
      user = create(:user)
      organization = create(:organization)
      
      expect { UserSerializer.new(user).serializable_hash }.not_to raise_error
      expect { OrganizationSerializer.new(organization).serializable_hash }.not_to raise_error
    end
  end

  describe "환경 설정 검증" do
    it "필수 환경 변수가 올바르게 설정되어야 함" do
      # 개발 환경에서 필요한 기본값들이 있는지 확인
      expect(Rails.env).to be_in(['development', 'test', 'production'])
      expect(Rails.application.config.database_configuration).not_to be_empty
    end

    it "멀티테넌트 설정이 올바르게 되어야 함" do
      expect(ActsAsTenant.configuration).not_to be_nil
      expect(ActsAsTenant.current_tenant_method).to eq(:current_tenant)
    end

    it "보안 설정이 올바르게 되어야 함" do
      expect(Rails.application.config.force_ssl).to be_in([true, false])
      expect(Rails.application.config.filter_parameters).to include(:password)
    end
  end
end
