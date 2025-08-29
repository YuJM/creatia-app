Rails.application.routes.draw do
  # Health check and system routes (모든 서브도메인에서 접근 가능)
  get "up" => "rails/health#show", as: :rails_health_check
  
  # Webhook routes (모든 서브도메인에서 접근 가능)
  namespace :webhooks do
    post 'github/push', to: 'github#push'
    post 'github/issues', to: 'github#issues'
    post 'github/pull_request', to: 'github#pull_request'
  end
  
  # Development routes
  mount Hotwire::Livereload::Engine => "/hotwire-livereload" if Rails.env.development?
  
  # 테넌트 전환 API (모든 서브도메인에서 접근 가능)
  resource :tenant_switcher, only: [:show] do
    collection do
      post :switch
      get :available
      get :quick_options
      get :history
      get :statistics
      post :leave
      get :context
      post :validate_access
      put :update_preferences
    end
  end
  
  # PWA routes
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  
  # =============================================================================
  # 메인 도메인 라우팅 (www 또는 서브도메인 없음)
  # =============================================================================
  constraints subdomain: /^(www)?$/ do
    devise_for :users, path_names: {
      sign_in: 'login',
      sign_out: 'logout',
      sign_up: 'register'
    }, as: :main_user, skip: [:omniauth_callbacks]
    
    get "pages/home"
    
    # 조직 관리 (전역)
    resources :organizations, only: [:index, :new, :create, :show, :update, :destroy] do
      member do
        post :switch
      end
    end
    
    # 사용자 관리 (전역)
    resources :users, only: [:index, :show, :edit, :update, :destroy]
    
    # 메인 랜딩 페이지
    root "landing#index"
  end
  
  # =============================================================================
  # 인증 전용 서브도메인 (auth.creatia.io)
  # =============================================================================
  constraints subdomain: 'auth' do
    devise_for :users, controllers: {
      omniauth_callbacks: 'users/omniauth_callbacks',
      sessions: 'users/sessions',
      registrations: 'users/registrations',
      passwords: 'users/passwords',
      confirmations: 'users/confirmations',
      unlocks: 'users/unlocks'
    }, path: '', path_names: {
      sign_in: 'login',
      sign_out: 'logout',
      sign_up: 'register'
    }, as: :auth_user
    
    # SSO 관련 라우트들
    devise_scope :user do
      get 'organization_selection', to: 'users/sessions#organization_selection', as: :organization_selection
      post 'switch_to_organization', to: 'users/sessions#switch_to_organization', as: :switch_to_organization
      get 'access_denied', to: 'users/sessions#access_denied', as: :access_denied
    end
    
    # 조직 선택 및 전환 (기존 조직 컨트롤러 루트)
    resources :organizations, only: [:index, :show] do
      member do
        post :switch
      end
    end
    
    # 백워드 호환성을 위한 추가 라우트
    get 'switch/:subdomain', to: 'users/sessions#switch_to_organization', as: :legacy_switch_to_organization
    
    root "pages#home", as: :auth_root
  end
  
  # =============================================================================
  # 조직별 테넌트 라우팅 ({org}.creatia.io)
  # =============================================================================
  constraints subdomain: /^(?!www|auth|api|admin)[\w\-]+$/ do
    # 조직 컨텍스트에서는 간단한 인증만
    devise_scope :user do
      get 'login', to: redirect { |params, request| 
        subdomain = DomainService.extract_subdomain(request)
        DomainService.login_url(subdomain)
      }
      get 'users/login', to: redirect { |params, request|
        subdomain = DomainService.extract_subdomain(request)
        DomainService.login_url(subdomain)
      }
      delete 'logout', to: 'devise/sessions#destroy'
    end
    
    # 조직 대시보드
    root "organizations#dashboard", as: :tenant_root
    get 'dashboard', to: 'organizations#dashboard'
    
    # 현재 조직 정보
    resource :organization, only: [:show, :edit, :update] do
      resources :organization_memberships, path: 'members', except: [:new] do
        member do
          patch :toggle_active
        end
        collection do
          post :invite
        end
      end
    end
    
    # 테넌트별 리소스들
    resources :tasks do
      member do
        patch :assign
        patch :change_status, path: 'status'
        patch :reorder
        get :metrics  # 새로 추가
      end
      collection do
        get :stats
      end
    end
    
    # 추후 추가될 테넌트별 리소스들
    # resources :projects
    # resources :sprints
    # resources :teams
    # resources :reports
    
    # 사용자 프로필 (조직 컨텍스트)
    resource :profile, controller: 'users', only: [:show, :edit, :update]
    
    # 조직 설정 (관리자/소유자만)
    namespace :settings do
      resource :organization, only: [:show, :edit, :update]
      resources :members, controller: 'organization_memberships'
      resource :billing, only: [:show, :edit, :update]
      resource :integrations, only: [:show, :update]
    end
  end
  
  # =============================================================================
  # API 라우팅 (api.creatia.io)
  # =============================================================================
  constraints subdomain: 'api' do
    namespace :api do
      namespace :v1 do
        # API 인증
        post 'auth/login', to: 'auth#login'
        post 'auth/logout', to: 'auth#logout'
        get 'auth/me', to: 'auth#me'
        
        # Health Check Endpoints
        namespace :health do
          get 'status', to: 'health#status'
          get 'ping', to: 'health#ping'
          get 'mongodb', to: 'health#mongodb'
          get 'postgresql', to: 'health#postgresql'
          get 'redis', to: 'health#redis'
          get 'detailed', to: 'health#detailed'
        end

        # Notification Endpoints
        resources :notifications, only: [:index, :show] do
          member do
            post 'read', to: 'notifications#mark_as_read'
            post 'dismiss'
            post 'archive'
            post 'interaction', to: 'notifications#track_interaction'
          end
          
          collection do
            get 'summary'
            get 'unread_count'
            post 'mark_all_read', to: 'notifications#mark_all_as_read'
            get 'preferences'
            put 'preferences', to: 'notifications#update_preferences'
            post 'test', to: 'notifications#send_test'
          end
        end
        
        # 조직 API
        resources :organizations do
          resources :tasks
          resources :organization_memberships, path: 'members'
        end
      end
    end
  end
  
  # =============================================================================
  # 관리자 라우팅 (admin.creatia.io)
  # =============================================================================
  constraints subdomain: 'admin' do
    namespace :admin do
      root "dashboard#index", as: :admin_root
      
      # MongoDB Monitoring Dashboard
      resources :mongodb_monitoring, only: [:index] do
        collection do
          get 'metrics'
          get 'trends'
          get 'slow_queries'
          get 'collections'
          get 'connections'
          post 'refresh'
          get 'export'
        end
      end
      
      resources :organizations do
        resources :organization_memberships, path: 'members'
      end
      resources :users
      resources :system_settings, only: [:index, :show, :update]
    end
  end
  
  # =============================================================================
  # 폴백 라우팅 (알 수 없는 서브도메인)
  # =============================================================================
  get '*path', to: 'application#route_not_found', constraints: lambda { |request|
    subdomain = DomainService.extract_subdomain(request)
    subdomain.present? && 
    !DomainService.reserved_subdomain?(subdomain) &&
    !Organization.exists?(subdomain: subdomain)
  }
end
