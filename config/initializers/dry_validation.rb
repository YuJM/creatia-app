# frozen_string_literal: true

require 'dry-validation'

# 한국어 에러 메시지 설정
Dry::Validation.load_extensions(:hints)

# 기본 Contract 클래스
class ApplicationContract < Dry::Validation::Contract
  config.messages.default_locale = :ko
  config.messages.load_paths << Rails.root.join('config/locales/dry_validation.ko.yml')
end