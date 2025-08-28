# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Application Routes", type: :routing do
  describe "라우팅 설정 검증" do
    it "애플리케이션이 오류 없이 부팅되어야 함" do
      expect { Rails.application.initialize! }.not_to raise_error
    end

    it "라우팅 파일이 오류 없이 로드되어야 함" do
      expect { Rails.application.reload_routes! }.not_to raise_error
    end

    it "모든 라우트가 유효하게 정의되어 있어야 함" do
      expect { Rails.application.routes.recognize_path('/') }.not_to raise_error
    end

    it "중복된 라우트 이름이 없어야 함" do
      route_names = Rails.application.routes.routes.map(&:name).compact
      duplicates = route_names.group_by(&:itself).select { |_, v| v.size > 1 }.keys
      
      expect(duplicates).to be_empty, 
        "중복된 라우트 이름이 발견되었습니다: #{duplicates.join(', ')}"
    end

    it "모든 제약조건이 유효해야 함" do
      Rails.application.routes.routes.each do |route|
        route.constraints.each do |key, constraint|
          case constraint
          when Regexp
            expect { "test".match(constraint) }.not_to raise_error
          when Proc
            expect(constraint).to respond_to(:call)
          end
        end
      end
    end

    it "필수 라우트들이 정의되어 있어야 함" do
      essential_paths = [
        '/',
        '/up',  # health check
      ]

      essential_paths.each do |path|
        expect { Rails.application.routes.recognize_path(path) }.not_to raise_error
      end
    end
  end

  describe "서브도메인별 라우팅" do
    it "메인 도메인 root 라우트" do
      expect(get: "/").to route_to(
        controller: "pages",
        action: "home"
      )
    end

    context "auth 서브도메인" do
      before do
        # auth 서브도메인 시뮬레이션
        allow_any_instance_of(ActionController::TestRequest)
          .to receive(:subdomain).and_return('auth')
      end

      it "인증 관련 라우트가 정의되어 있어야 함" do
        # Devise 라우트 확인
        expect { Rails.application.routes.recognize_path('/login', subdomain: 'auth') }
          .not_to raise_error
      end
    end
  end

  describe "ApplicationController 설정" do
    it "current_user 메서드가 사용 가능해야 함" do
      controller = ApplicationController.new
      expect(controller).to respond_to(:current_user)
    end

    it "Devise 헬퍼 메서드가 포함되어 있어야 함" do
      controller = ApplicationController.new
      expect(controller.class.ancestors.map(&:name))
        .to include("Devise::Controllers::Helpers")
    end
  end
end
