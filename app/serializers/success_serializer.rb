# frozen_string_literal: true

# SuccessSerializer - 성공 응답을 위한 범용 직렬화
class SuccessSerializer < BaseSerializer
  # 기본 속성
  attribute :success do
    true
  end
  
  attribute :message do |object|
    object[:message] || object['message'] || '성공적으로 처리되었습니다.'
  end
  
  # 선택적 데이터 속성
  attribute :data, if: proc { |object| 
    object.is_a?(Hash) && (object[:data] || object['data'])
  } do |object|
    object[:data] || object['data']
  end
  
  # 선택적 태스크 속성
  attribute :task, if: proc { |object, params|
    params.is_a?(Hash) && params[:task]
  } do |object, params|
    task = params[:task]
    if task && params[:task_serializer]
      params[:task_serializer].new(task, params: params).serializable_hash
    else
      nil
    end
  end
end