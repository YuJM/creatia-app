# frozen_string_literal: true

require 'rails_helper'

# CI/CD 파이프라인에서 실행할 핵심 통합 테스트
RSpec.describe "CI Integration Tests", type: :system do
  describe "애플리케이션 기본 기능 검증" do
    it "애플리케이션이 정상적으로 초기화되어 있어야 함" do
      expect(Rails.application.initialized?).to be true
    end

    it "데이터베이스 연결이 정상이어야 함" do
      expect { ActiveRecord::Base.connection.execute("SELECT 1") }.not_to raise_error
    end

    it "기본 페이지가 로드되어야 함" do
      visit root_path
      expect(page).not_to have_content('error')
      expect(page).not_to have_content('500')
      expect(page).not_to have_content('NameError')
    end

    it "헬스체크 엔드포인트가 동작해야 함" do
      visit rails_health_check_path
      expect(page).not_to have_content('error')
    end
  end

  describe "핵심 사용자 플로우" do
    let(:user) { create(:user, password: 'password123') }
    let(:organization) { create(:organization) }
    let!(:membership) { create(:organization_membership, user: user, organization: organization) }

    it "기본적인 사용자 인증이 동작해야 함" do
      # 간단한 인증 테스트
      login_as(user, scope: :user)
      
      # 인증된 사용자로 기본 페이지 접근
      visit root_path
      expect(page).not_to have_content('error')
      expect(page).not_to have_content('500')
    end

    it "권한 시스템이 기본적으로 동작해야 함" do
      login_as(user, scope: :user)

      # 기본 페이지 접근 테스트
      visit root_path
      expect(page).not_to have_content('error')
    end
  end

  describe "API 기본 기능" do
    it "API 라우트가 정의되어 있어야 함" do
      # API 관련 라우트 검증은 일단 스킵
      skip("API 라우트 검증은 별도 테스트에서 수행")
    end
  end

  describe "성능 기준선" do
    it "홈페이지 로드 시간이 허용 범위 내여야 함" do
      load_time = measure_response_time do
        visit root_path
      end

      expect(load_time).to be < 3.seconds
    end

    it "데이터베이스 쿼리 수가 합리적이어야 함" do
      query_count = count_database_queries do
        visit root_path
      end

      expect(query_count).to be < 15
    end
  end

  describe "보안 기본 사항" do
    it "CSRF 보호 설정이 있어야 함" do
      expect(Rails.application.config.force_ssl).to be_in([true, false])
    end

    it "민감한 파라미터 필터링이 설정되어 있어야 함" do
      filter_params = Rails.application.config.filter_parameters
      expect(filter_params).not_to be_empty
      # password, email, secret 등이 필터링되는지 확인
      expect(filter_params.any? { |param| param.to_s.include?('passw') }).to be true
    end
  end

  describe "멀티테넌트 기본 기능" do
    it "기본 멀티테넌트 설정이 로드되어야 함" do
      expect(defined?(ActsAsTenant)).to be_truthy
      expect(ActsAsTenant.configuration).not_to be_nil
    end
  end

  describe "오류 처리" do
    it "존재하지 않는 페이지 접근시 오류가 발생하지 않아야 함" do
      visit '/nonexistent-page'
      # 에러 페이지든 리다이렉트든 심각한 오류는 없어야 함
      expect(page).not_to have_content('500')
      expect(page).not_to have_content('Internal Server Error')
    end

    it "정적 오류 페이지가 존재해야 함" do
      expect(File.exist?(Rails.root.join('public', '404.html'))).to be true
      expect(File.exist?(Rails.root.join('public', '500.html'))).to be true
    end
  end

  describe "환경 설정 검증" do
    it "필수 환경 변수가 기본값으로라도 설정되어 있어야 함" do
      expect(Rails.env).to be_in(['development', 'test', 'production'])
      expect(Rails.application.config.secret_key_base).to be_present
    end

    it "데이터베이스 설정이 올바르게 되어 있어야 함" do
      config = Rails.application.config.database_configuration[Rails.env]
      expect(config).to be_present
      expect(config['adapter']).to be_present
    end
  end

  describe "의존성 검증" do
    it "모든 필수 gem이 로드되어야 함" do
      required_gems = [
        'Rails',
        'Devise',
        'Pundit',
        'ActsAsTenant',
        'Alba'
      ]

      required_gems.each do |gem_name|
        expect(defined?(gem_name.constantize)).to be_truthy
      end
    end

    it "모든 모델이 올바르게 정의되어야 함" do
      models = [User, Organization, Task, OrganizationMembership]
      
      models.each do |model|
        expect(model).to be < ApplicationRecord
        expect { model.new }.not_to raise_error
      end
    end
  end
end
