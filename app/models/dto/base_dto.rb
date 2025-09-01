# frozen_string_literal: true

require "dry-struct"

module Dto
  # BaseDto - dry-struct 기반 공통 DTO
  class BaseDto < Dry::Struct
    transform_keys(&:to_sym)

    # Alba/API 응답용 직렬화
    def to_api_response
      attributes.compact
    end

    # 해시 변환
    def to_h
      attributes.transform_keys(&:to_s)
    end

    # JSON 직렬화
    def as_json(options = {})
      to_h.merge(computed_attributes.transform_keys(&:to_s))
    end

    # 계산된 속성 (하위 클래스에서 오버라이드)
    def computed_attributes
      {}
    end

    # 팩토리 메서드 - Service Layer에서 사용
    def self.from_model(model, enriched_data = {})
      new(build_attributes(model, enriched_data))
    end

    # 속성 빌더 (하위 클래스에서 구현)
    def self.build_attributes(model, enriched_data)
      raise NotImplementedError, "Subclass must implement build_attributes"
    end
  end
end
