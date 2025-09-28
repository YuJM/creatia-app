# frozen_string_literal: true

# 애플리케이션 전체에서 사용되는 주요 경로 상수들을 정의
module AppRoutes
  # 인증 관련 경로 (auth 서브도메인 사용)
  module AuthRoutes
    class << self
      # SSO를 위한 auth 서브도메인 URL 생성
      # 모든 인증은 auth.creatia.local을 통해 처리됩니다
      
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
      
      # SSO 리다이렉트 URL (조직별 접근 시)
      def sso_redirect_url(organization_subdomain)
        DomainService.auth_url("login?return_to=#{organization_subdomain}")
      end
    end
  end
  
  # 조직 관련 경로
  module OrganizationRoutes
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
  
  # 태스크 관련 경로 (web 네임스페이스 제거)
  module TaskRoutes
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
  module PublicRoutes
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
  module AdminRoutes
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
  module ApiRoutes
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
      OrganizationRoutes::DASHBOARD_PATH
    end
    
    def after_sign_out_path
      PublicRoutes::HOME_PATH
    end
    
    # 조직 서브도메인이 있는 경우의 루트 경로
    def organization_root_path
      OrganizationRoutes::DASHBOARD_PATH
    end
    
    # 메인 도메인 루트 경로
    def main_root_path
      PublicRoutes::HOME_PATH
    end
  end
  
  # 기존 코드와의 호환성을 위한 alias (deprecated)
  Auth = AuthRoutes
  Organization = OrganizationRoutes
  Task = TaskRoutes
  Public = PublicRoutes
  Admin = AdminRoutes
  Api = ApiRoutes
end