# frozen_string_literal: true

# TaskSerializer - 태스크 정보를 직렬화합니다.
class TaskSerializer < BaseSerializer
  # 기본 속성들
  attributes :id, :title, :description, :status, :priority, :position, :due_date, :created_at, :updated_at
  
  # 표시용 이름들
  attribute :status_display_name do |task|
    task.status_display_name
  end
  
  attribute :priority_display_name do |task|
    task.priority_display_name
  end
  
  attribute :priority_color do |task|
    task.priority_color
  end
  
  # 할당된 사용자 정보
  attribute :assigned_user, if: proc { |task, params| task.assigned? } do |task|
    user = task.assigned_user
    if user.is_a?(User)
      {
        id: user.id,
        email: user.email,
        display_name: user.name || user.email.split('@').first.capitalize,
        type: 'User'
      }
    else
      {
        id: user.id,
        name: user.try(:name) || user.try(:title) || 'Unknown',
        type: user.class.name
      }
    end
  end
  
  # 조직 정보 (간소화된 버전)
  attribute :organization, if: proc { |task, params| 
    !params[:skip_organization] 
  } do |task|
    {
      id: task.organization.id,
      name: task.organization.name,
      subdomain: task.organization.subdomain
    }
  end
  
  # 상태 정보
  attribute :status_info do |task|
    {
      completed: task.completed?,
      in_progress: task.in_progress?,
      can_start: task.status == 'todo',
      can_complete: task.status.in?(%w[todo in_progress review])
    }
  end
  
  # 기한 관련 정보
  attribute :due_info, if: proc { |task, params| task.due_date.present? } do |task, params|
    info = {
      overdue: task.overdue?,
      due_soon: task.due_soon?,
      days_remaining: task.due_date.present? ? (task.due_date.to_date - Date.current).to_i : nil
    }
    
    if params[:time_helper]
      info[:due_date_formatted] = params[:time_helper].time_ago_in_words(task.due_date)
    end
    
    info
  end
  
  # 권한 정보 (현재 사용자 기준)
  attribute :permissions, if: proc { |task, params| 
    params[:current_user].present? 
  } do |task, params|
    user = params[:current_user]
    policy = TaskPolicy.new(user, task)
    
    {
      can_update: policy.update?,
      can_delete: policy.destroy?,
      can_assign: policy.assign?,
      can_change_status: policy.change_status?,
      can_change_priority: policy.change_priority?,
      can_reorder: policy.reorder?,
      is_assigned_to_me: task.assigned_user == user
    }
  end
  
  # 생성일로부터 경과 시간
  attribute :created_ago, if: proc { |task, params| 
    params[:time_helper].present? 
  } do |task, params|
    params[:time_helper].time_ago_in_words(task.created_at)
  end
  
  # 태스크 통계 (목록 조회시에만)
  attribute :stats, if: proc { |task, params| 
    params[:include_stats] 
  } do |task|
    {
      comments_count: 0, # 추후 댓글 기능 추가시
      attachments_count: 0, # 추후 첨부파일 기능 추가시
      subtasks_count: 0 # 추후 하위 태스크 기능 추가시
    }
  end
end
