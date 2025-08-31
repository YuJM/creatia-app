# frozen_string_literal: true

# 애플리케이션 전체에서 사용되는 주요 경로 상수들을 정의
module AppRoutes
  # 인증 관련 경로 (auth 서브도메인 사용)
  module Auth
    class << self
      # SSO를 위한 auth 서브도메인 URL 생성
      def register_url
        DomainService.auth_url('register')
      end
      
      def login_url
        DomainService.auth_url('login')
      end
      
      def logout_url
        DomainService.auth_url('logout')
      end
      
      def password_reset_url
        DomainService.auth_url('password/new')
      end
      
      def profile_edit_url
        DomainService.auth_url('edit')
      end
      
      # 레거시 경로 (메인 도메인용)
      REGISTER_PATH = '/users/register'
      LOGIN_PATH = '/users/login'
      LOGOUT_PATH = '/users/logout'
      PASSWORD_RESET_PATH = '/users/password/new'
      PROFILE_EDIT_PATH = '/users/edit'
    end
  end
  
  # 조직 관련 경로
  module Organization
    # 조직 목록
    INDEX_PATH = '/organizations'
    
    # 새 조직 생성
    NEW_PATH = '/organizations/new'
    
    # 조직 대시보드
    DASHBOARD_PATH = '/dashboard'
    
    # 조직 설정
    SETTINGS_PATH = '/organization/settings'
    
    # 멤버 관리
    MEMBERS_PATH = '/organization/members'
  end
  
  # 태스크 관련 경로
  module Task
    # 태스크 목록
    INDEX_PATH = '/tasks'
    
    # 새 태스크
    NEW_PATH = '/tasks/new'
    
    # 캘린더 뷰
    CALENDAR_PATH = '/tasks/calendar'
    
    # 칸반 보드
    BOARD_PATH = '/tasks/board'
  end
  
  # 랜딩 및 공개 페이지
  module Public
    # 홈 (랜딩)
    HOME_PATH = '/'
    
    # 가격 정책
    PRICING_PATH = '/pricing'
    
    # 기능 소개
    FEATURES_PATH = '/features'
    
    # 회사 소개
    ABOUT_PATH = '/about'
    
    # 문의하기
    CONTACT_PATH = '/contact'
  end
  
  # 관리자 경로
  module Admin
    # 관리자 대시보드
    DASHBOARD_PATH = '/admin'
    
    # 조직 관리
    ORGANIZATIONS_PATH = '/admin/organizations'
    
    # 사용자 관리
    USERS_PATH = '/admin/users'
    
    # 시스템 설정
    SETTINGS_PATH = '/admin/settings'
  end
  
  # API 경로
  module Api
    # API 베이스 경로
    BASE_PATH = '/api/v1'
    
    # 조직 API
    ORGANIZATIONS_PATH = '/api/v1/organizations'
    
    # 태스크 API
    TASKS_PATH = '/api/v1/tasks'
    
    # 웹훅
    WEBHOOKS_PATH = '/webhooks'
  end
  
  # 헬퍼 메서드들
  class << self
    # 로그인 여부에 따른 리다이렉트 경로
    def after_sign_in_path
      Organization::DASHBOARD_PATH
    end
    
    def after_sign_out_path
      Public::HOME_PATH
    end
    
    # 조직 서브도메인이 있는 경우의 루트 경로
    def organization_root_path
      Organization::DASHBOARD_PATH
    end
    
    # 메인 도메인 루트 경로
    def main_root_path
      Public::HOME_PATH
    end
  end
end