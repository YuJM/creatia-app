# frozen_string_literal: true

# DashboardCustomizationSerializer - 대시보드 커스터마이제이션 응답 직렬화
class DashboardCustomizationSerializer < BaseSerializer
  # 성공 플래그
  attribute :success do |data|
    data[:success] != false
  end
  
  # 메시지
  attribute :message, if: proc { |data|
    data.is_a?(Hash) && data[:message]
  } do |data|
    data[:message]
  end
  
  # 에러
  attribute :error, if: proc { |data|
    data.is_a?(Hash) && data[:error]
  } do |data|
    data[:error]
  end
  
  # 위젯
  attribute :widget, if: proc { |data|
    data.is_a?(Hash) && data[:widget]
  } do |data|
    data[:widget]
  end
  
  # 위치
  attribute :position, if: proc { |data|
    data.is_a?(Hash) && data[:position]
  } do |data|
    data[:position]
  end
  
  # 프리뷰 데이터
  attribute :preview, if: proc { |data|
    data.is_a?(Hash) && data[:preview]
  } do |data|
    data[:preview]
  end
  
  # 사용자 설정
  attribute :preferences, if: proc { |data|
    data.is_a?(Hash) && data[:preferences]
  } do |data|
    data[:preferences]
  end
  
  # 레이아웃
  attribute :layouts, if: proc { |data|
    data.is_a?(Hash) && data[:layouts]
  } do |data|
    data[:layouts]
  end
  
  # 위젯 설정
  attribute :widget_configurations, if: proc { |data|
    data.is_a?(Hash) && data[:widget_configurations]
  } do |data|
    data[:widget_configurations]
  end
  
  # 사용 가능한 위젯들
  attribute :available_widgets, if: proc { |data|
    data.is_a?(Hash) && data[:available_widgets]
  } do |data|
    data[:available_widgets]
  end
  
  # 위젯 옵션
  attribute :widget_options, if: proc { |data|
    data.is_a?(Hash) && data[:widget_options]
  } do |data|
    data[:widget_options]
  end
  
  # 상태
  attribute :status, if: proc { |data|
    data.is_a?(Hash) && data[:status]
  } do |data|
    data[:status]
  end
end