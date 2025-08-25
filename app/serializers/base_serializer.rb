# frozen_string_literal: true

# BaseSerializer - 모든 Alba serializer의 부모 클래스
# JSON 응답의 키를 camelCase로 변환하는 기본 설정을 제공합니다.
class BaseSerializer
  include Alba::Resource
  
  # 모든 키를 camelCase로 변환
  transform_keys :lower_camel
end
