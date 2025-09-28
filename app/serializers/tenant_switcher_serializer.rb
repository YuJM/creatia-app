# frozen_string_literal: true

# TenantSwitcherSerializer - 조직 전환 관련 데이터 직렬화
class TenantSwitcherSerializer < BaseSerializer
  # 성공/실패 플래그
  attribute :success do |data|
    data[:success] != false
  end
  
  # 메시지
  attribute :message, if: proc { |data| 
    data.is_a?(Hash) && data[:message]
  } do |data|
    data[:message]
  end
  
  # 에러 메시지
  attribute :error, if: proc { |data| 
    data.is_a?(Hash) && data[:error]
  } do |data|
    data[:error]
  end
  
  # 데이터 속성
  attribute :data, if: proc { |data| 
    data.is_a?(Hash) && data[:data]
  } do |data|
    data[:data]
  end
  
  # 조직 목록
  attribute :organizations, if: proc { |data| 
    data.is_a?(Hash) && data[:organizations]
  } do |data|
    data[:organizations]
  end
  
  # 현재 조직 정보
  attribute :current_organization, if: proc { |data| 
    data.is_a?(Hash) && data[:current_organization]
  } do |data|
    data[:current_organization]
  end
  
  # 빠른 옵션들
  attribute :quick_options, if: proc { |data| 
    data.is_a?(Hash) && data[:quick_options]
  } do |data|
    data[:quick_options]
  end
  
  # 이력
  attribute :history, if: proc { |data| 
    data.is_a?(Hash) && data[:history]
  } do |data|
    data[:history]
  end
  
  # 통계
  attribute :statistics, if: proc { |data| 
    data.is_a?(Hash) && data[:statistics]
  } do |data|
    data[:statistics]
  end
  
  # 컨텍스트 정보
  attribute :context, if: proc { |data| 
    data.is_a?(Hash) && data[:context]
  } do |data|
    data[:context]
  end
  
  # 리다이렉트 URL
  attribute :redirect_url, if: proc { |data| 
    data.is_a?(Hash) && data[:redirect_url]
  } do |data|
    data[:redirect_url]
  end
  
  # 업데이트된 설정
  attribute :updated_preferences, if: proc { |data| 
    data.is_a?(Hash) && data[:updated_preferences]
  } do |data|
    data[:updated_preferences]
  end
end