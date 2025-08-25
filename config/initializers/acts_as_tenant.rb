# frozen_string_literal: true

ActsAsTenant.configure do |config|
  # 개발 환경에서는 테넌트 요구사항을 완화
  config.require_tenant = Rails.env.production?
end
