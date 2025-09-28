# frozen_string_literal: true

# RoadmapSerializer - 로드맵 관련 응답 직렬화
class RoadmapSerializer < BaseSerializer
  # 성공 플래그
  attribute :success do |data|
    data[:success] != false
  end
  
  # 로드맵 목록
  attribute :roadmaps, if: proc { |data|
    data.is_a?(Hash) && data[:roadmaps]
  } do |data|
    data[:roadmaps]
  end
  
  # 로드맵 단일
  attribute :roadmap, if: proc { |data|
    data.is_a?(Hash) && data[:roadmap]
  } do |data|
    data[:roadmap]
  end
  
  # 데이터
  attribute :data, if: proc { |data|
    data.is_a?(Hash) && data[:data]
  } do |data|
    data[:data]
  end
  
  # 타임라인
  attribute :timeline, if: proc { |data|
    data.is_a?(Hash) && data[:timeline]
  } do |data|
    data[:timeline]
  end
  
  # 타임라인 데이터
  attribute :timeline_data, if: proc { |data|
    data.is_a?(Hash) && data[:timeline_data]
  } do |data|
    data[:timeline_data]
  end
  
  # 의존성 그래프
  attribute :dependency_graph, if: proc { |data|
    data.is_a?(Hash) && data[:dependency_graph]
  } do |data|
    data[:dependency_graph]
  end
  
  # 리스크 분석
  attribute :risk_analysis, if: proc { |data|
    data.is_a?(Hash) && data[:risk_analysis]
  } do |data|
    data[:risk_analysis]
  end
  
  # 진행률 메트릭
  attribute :progress_metrics, if: proc { |data|
    data.is_a?(Hash) && data[:progress_metrics]
  } do |data|
    data[:progress_metrics]
  end
  
  # 간트 차트
  attribute :gantt, if: proc { |data|
    data.is_a?(Hash) && data[:gantt]
  } do |data|
    data[:gantt]
  end
  
  # 의존성
  attribute :dependencies, if: proc { |data|
    data.is_a?(Hash) && data[:dependencies]
  } do |data|
    data[:dependencies]
  end
  
  # 임계 경로
  attribute :critical_path, if: proc { |data|
    data.is_a?(Hash) && data[:critical_path]
  } do |data|
    data[:critical_path]
  end
  
  # 메트릭
  attribute :metrics, if: proc { |data|
    data.is_a?(Hash) && data[:metrics]
  } do |data|
    data[:metrics]
  end
  
  # 뷰 타입
  attribute :view, if: proc { |data|
    data.is_a?(Hash) && data[:view]
  } do |data|
    data[:view]
  end
  
  # 업데이트 시간
  attribute :updated_at, if: proc { |data|
    data.is_a?(Hash) && data[:updated_at]
  } do |data|
    data[:updated_at]
  end
  
  # 에러
  attribute :errors, if: proc { |data|
    data.is_a?(Hash) && data[:errors]
  } do |data|
    data[:errors]
  end
end