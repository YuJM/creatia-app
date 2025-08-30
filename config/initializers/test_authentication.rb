# frozen_string_literal: true

# 테스트 환경에서 자동 인증을 지원하는 설정
if Rails.env.development? || Rails.env.test?
  Rails.application.config.to_prepare do
    ApplicationController.class_eval do
      # 테스트용 자동 로그인 메서드 추가
      def auto_login_for_test
        return unless params[:test_user_email].present?
        return unless Rails.env.development? || Rails.env.test?
        
        user = User.find_by(email: params[:test_user_email])
        if user
          sign_in(user, scope: :user)
          Rails.logger.info "Test auto-login for #{user.email}"
        end
      end
      
      # 테스트 환경에서만 before_action 추가
      before_action :auto_login_for_test, if: -> { params[:test_user_email].present? }
    end
  end
end