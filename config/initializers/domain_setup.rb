# frozen_string_literal: true

# 개발환경에서 멀티테넌트 도메인 설정 도움말 출력
if Rails.env.development?
  Rails.application.config.after_initialize do
    DomainService.development_hosts_info
  end
end
