# frozen_string_literal: true

# ErrorSerializer - 에러 응답을 표준화된 형태로 직렬화합니다.
# 
# 사용 예시:
#   ErrorSerializer.new(errors: ["Title can't be blank"], success: false).serializable_hash
#   # => { "success" => false, "errors" => ["Title can't be blank"], "error" => "Title can't be blank" }
class ErrorSerializer < BaseSerializer
  # 기본 에러 응답 구조
  attributes :success, :errors, :error
  
  # 에러 메시지들을 단일 문자열로 결합
  attribute :error do |object|
    case object[:errors]
    when Array
      object[:errors].join(", ")
    when String
      object[:errors]
    when ActiveModel::Errors
      object[:errors].full_messages.join(", ")
    else
      object[:errors].to_s
    end
  end
  
  # 에러 메시지들을 배열 형태로 반환
  attribute :errors do |object|
    case object[:errors]
    when Array
      object[:errors]
    when String
      [object[:errors]]
    when ActiveModel::Errors
      object[:errors].full_messages
    else
      [object[:errors].to_s]
    end
  end
end
