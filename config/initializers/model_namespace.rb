# frozen_string_literal: true

# 네임스페이스 충돌 방지를 위한 모델 참조 설정
# AppRoutes 모듈의 하위 모듈(Task, Organization 등)과 
# 실제 모델 클래스가 충돌하는 것을 방지합니다.

# 모든 컨트롤러에서 모델을 참조할 때 루트 네임스페이스를 사용하도록 권장
# 예: Task 대신 ::Task, Organization 대신 ::Organization

Rails.application.config.after_initialize do
  # 개발 환경에서 네임스페이스 충돌 감지
  if Rails.env.development?
    # AppRoutes의 하위 모듈과 같은 이름의 모델이 있는지 확인
    conflicting_names = %w[Task Organization Admin]
    
    conflicting_names.each do |name|
      if AppRoutes.const_defined?(name) && Object.const_defined?(name)
        Rails.logger.warn "⚠️  네임스페이스 충돌 가능성: AppRoutes::#{name}와 ::#{name} 모델이 공존합니다."
        Rails.logger.warn "   컨트롤러에서는 ::#{name}를 사용하여 모델을 참조하세요."
      end
    end
  end
end

# 모델 참조 헬퍼 모듈
module ModelNamespace
  extend ActiveSupport::Concern
  
  included do
    # 자주 사용되는 모델들을 메서드로 정의
    # 이렇게 하면 컨트롤러에서 task_model.accessible_by 형태로 사용 가능
    
    def task_model
      ::Task
    end
    
    def organization_model
      ::Organization
    end
    
    def user_model
      ::User
    end
    
    def sprint_model
      ::Sprint
    end
    
    def team_model
      ::Team
    end
    
    def service_model
      ::Service
    end
  end
end

# ApplicationController에 자동으로 포함되도록 설정
ActiveSupport.on_load(:action_controller) do
  include ModelNamespace
end