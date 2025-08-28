# frozen_string_literal: true

# OrganizationDashboardSerializer - 조직 대시보드 데이터 직렬화
class OrganizationDashboardSerializer < BaseSerializer
  # 성공 플래그
  attribute :success do
    true
  end
  
  # 조직 정보
  attribute :organization, if: proc { |data, params|
    data.is_a?(Hash) && data[:organization]
  } do |data, params|
    org = data[:organization]
    if org
      OrganizationSerializer.new(org, params: params).serializable_hash
    end
  end
  
  # 최근 태스크들
  attribute :recent_tasks, if: proc { |data, params|
    data.is_a?(Hash) && data[:recent_tasks]
  } do |data, params|
    tasks = data[:recent_tasks]
    if tasks
      tasks.map { |task|
        TaskSerializer.new(task, params: params).serializable_hash
      }
    end
  end
  
  # 다가올 스프린트들
  attribute :upcoming_sprints, if: proc { |data, params|
    data.is_a?(Hash) && data[:upcoming_sprints]
  } do |data, params|
    sprints = data[:upcoming_sprints]
    if sprints
      sprints.map { |sprint|
        SprintSerializer.new(sprint, params: params).serializable_hash
      }
    end
  end
  
  # 대시보드 통계
  attribute :dashboard_stats, if: proc { |data|
    data.is_a?(Hash) && data[:dashboard_stats]
  } do |data|
    data[:dashboard_stats]
  end
  
  # 태스크 통계
  attribute :task_stats, if: proc { |data|
    data.is_a?(Hash) && data[:task_stats]
  } do |data|
    data[:task_stats]
  end
  
  # 멤버십 통계
  attribute :membership_stats, if: proc { |data|
    data.is_a?(Hash) && data[:membership_stats]
  } do |data|
    data[:membership_stats]
  end
  
  # 데이터 속성 (범용)
  attribute :data, if: proc { |data|
    data.is_a?(Hash) && data[:data]
  } do |data|
    data[:data]
  end
end