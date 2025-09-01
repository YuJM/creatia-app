# frozen_string_literal: true

# Rails Icons 설정
# Phosphor 아이콘 라이브러리를 기본으로 사용
RailsIcons.configure do |config|
  # 기본 라이브러리 설정
  config.default_library = "phosphor"
  
  # 기본 변형(weight) 설정
  config.default_variant = "regular"
  
  # Phosphor 라이브러리 기본 설정
  config.libraries.phosphor.default_variant = "regular"
  
  # 각 변형별 기본 CSS 클래스 설정
  # Tailwind CSS의 size 유틸리티 사용
  config.libraries.phosphor.regular.default.css = "inline-block flex-shrink-0 size-5"
  config.libraries.phosphor.bold.default.css = "inline-block flex-shrink-0 size-5"
  config.libraries.phosphor.fill.default.css = "inline-block flex-shrink-0 size-5"
  config.libraries.phosphor.light.default.css = "inline-block flex-shrink-0 size-5"
  config.libraries.phosphor.duotone.default.css = "inline-block flex-shrink-0 size-5"
  config.libraries.phosphor.thin.default.css = "inline-block flex-shrink-0 size-5"
end
