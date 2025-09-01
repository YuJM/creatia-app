# app/services/task_service.rb
class TaskService
  extend Broadcastable
  
  class << self
    def create_task(params)
      # Service 확인
      service = Service.find(params[:service_id])
      
      # Task 생성
      task = Mongodb::MongoTask.create!(
        organization_id: service.organization_id,
        service_id: service.id,
        task_id: generate_task_id(service.id),
        title: params[:title],
        description: params[:description],
        task_type: params[:task_type] || 'feature',
        assignee_id: params[:assignee_id],
        assignee_name: get_assignee_name(params[:assignee_id]),
        priority: params[:priority] || 'medium',
        status: params[:status] || 'backlog',
        story_points: params[:story_points],
        original_estimate_hours: params[:estimate_hours],
        due_date: params[:due_date],
        labels: params[:labels] || [],
        epic_id: params[:epic_id],
        sprint_id: params[:sprint_id],
        milestone_id: params[:milestone_id]
      )
      
      # Sprint에 추가 (if sprint_id provided)
      if params[:sprint_id].present?
        sprint = Mongodb::MongoSprint.find(params[:sprint_id])
        sprint.add_task(task)
      end
      
      # 활동 로그
      log_task_activity(task, 'created')
      
      # 실시간 알림
      broadcast_task_created(task)
      
      task
    end
    
    def update_task(task_id, params)
      task = Mongodb::MongoTask.find(task_id)
      changes = {}
      
      # 변경 사항 추적
      params.each do |key, value|
        if task.respond_to?(key) && task[key] != value
          changes[key] = [task[key], value]
          task[key] = value
        end
      end
      
      # 특별 처리: assignee 변경
      if params[:assignee_id].present? && params[:assignee_id] != task.assignee_id
        task.assignee_name = get_assignee_name(params[:assignee_id])
        task.participants << params[:assignee_id] unless task.participants.include?(params[:assignee_id])
      end
      
      task.save!
      
      # 활동 로그
      log_task_activity(task, 'updated', changes) if changes.any?
      
      # 실시간 알림
      broadcast_task_updated(task, changes)
      
      task
    end
    
    def move_to_sprint(task_ids, sprint_id)
      tasks = Mongodb::MongoTask.where(:_id.in => task_ids)
      sprint = Mongodb::MongoSprint.find(sprint_id)
      
      moved_tasks = []
      
      tasks.each do |task|
        # 이전 Sprint에서 제거
        if task.sprint_id.present? && task.sprint_id != sprint_id
          old_sprint = Mongodb::MongoSprint.find(task.sprint_id)
          old_sprint.remove_task(task)
        end
        
        # 새 Sprint에 추가
        sprint.add_task(task)
        
        # 활동 로그
        log_task_activity(task, 'moved_to_sprint', {
          from_sprint: task.sprint_id,
          to_sprint: sprint_id
        })
        
        moved_tasks << task
      end
      
      # 실시간 알림
      broadcast_sprint_update(sprint)
      
      moved_tasks
    end
    
    def assign_task(task_id, assignee_id)
      task = Mongodb::MongoTask.find(task_id)
      old_assignee = task.assignee_id
      
      task.assignee_id = assignee_id
      task.assignee_name = get_assignee_name(assignee_id)
      task.participants << assignee_id unless task.participants.include?(assignee_id)
      task.save!
      
      # 활동 로그
      log_task_activity(task, 'assigned', {
        from: old_assignee,
        to: assignee_id
      })
      
      # 알림 전송
      notify_assignee(task, assignee_id)
      
      # 실시간 브로드캐스트
      broadcast_task_assigned(task, assignee_id)
      
      task
    end
    
    def update_status(task_id, new_status, user_id = nil)
      task = Mongodb::MongoTask.find(task_id)
      task.update_status(new_status, user_id || Current.user&.id)
      
      # Sprint 메트릭 업데이트
      if task.sprint_id.present?
        SprintService.send(:update_burndown_data, Mongodb::MongoSprint.find(task.sprint_id))
      end
      
      # 실시간 브로드캐스트
      broadcast_task_status_changed(task)
      
      task
    end
    
    def add_comment(task_id, comment_params)
      task = Mongodb::MongoTask.find(task_id)
      
      comment = Mongodb::MongoComment.create!(
        commentable_type: 'MongoTask',
        commentable_id: task_id,
        organization_id: task.organization_id,
        author_id: comment_params[:author_id] || Current.user&.id,
        author_name: get_user_name(comment_params[:author_id] || Current.user&.id),
        content: comment_params[:content],
        comment_type: comment_params[:type] || 'general',
        mentioned_user_ids: extract_mentions(comment_params[:content])
      )
      
      # Task 코멘트 카운트 업데이트
      task.add_comment(comment.author_id, comment.content)
      
      # 멘션 알림
      notify_mentioned_users(comment)
      
      # 실시간 브로드캐스트
      broadcast_comment_added(task, comment)
      
      comment
    end
    
    def add_subtask(task_id, subtask_params)
      task = Mongodb::MongoTask.find(task_id)
      
      subtask = task.add_subtask(
        subtask_params[:title],
        subtask_params[:assignee_id]
      )
      
      # 활동 로그
      log_task_activity(task, 'subtask_added', {
        subtask_title: subtask[:title]
      })
      
      # 실시간 브로드캐스트
      broadcast_task_updated(task, { subtasks: task.subtasks })
      
      subtask
    end
    
    def complete_subtask(task_id, subtask_id)
      task = Mongodb::MongoTask.find(task_id)
      task.complete_subtask(subtask_id)
      
      # 활동 로그
      log_task_activity(task, 'subtask_completed', {
        subtask_id: subtask_id
      })
      
      # 실시간 브로드캐스트
      broadcast_task_updated(task, { 
        subtasks: task.subtasks,
        completion_percentage: task.completion_percentage
      })
      
      task
    end
    
    def block_task(task_id, reason, blocking_task_ids = [])
      task = Mongodb::MongoTask.find(task_id)
      
      task.is_blocked = true
      task.blocked_reason = reason
      task.blocked_by_task_ids = blocking_task_ids
      task.save!
      
      # 활동 로그
      log_task_activity(task, 'blocked', {
        reason: reason,
        blocked_by: blocking_task_ids
      })
      
      # 알림
      notify_task_blocked(task)
      
      # 실시간 브로드캐스트
      broadcast_task_blocked(task)
      
      task
    end
    
    def unblock_task(task_id)
      task = Mongodb::MongoTask.find(task_id)
      
      task.is_blocked = false
      task.blocked_reason = nil
      task.blocked_by_task_ids = []
      task.save!
      
      # 활동 로그
      log_task_activity(task, 'unblocked')
      
      # 실시간 브로드캐스트
      broadcast_task_unblocked(task)
      
      task
    end
    
    def bulk_update_status(task_ids, new_status, user_id = nil)
      Mongodb::MongoTask.bulk_update_status(task_ids, new_status, user_id || Current.user&.id)
      
      # 실시간 브로드캐스트
      broadcast_bulk_update(task_ids, { status: new_status })
    end
    
    def search_tasks(params)
      query = Mongodb::MongoTask.all
      
      # 필터링
      query = query.where(organization_id: params[:organization_id]) if params[:organization_id]
      query = query.where(service_id: params[:service_id]) if params[:service_id]
      query = query.where(sprint_id: params[:sprint_id]) if params[:sprint_id]
      query = query.where(assignee_id: params[:assignee_id]) if params[:assignee_id]
      query = query.where(status: params[:status]) if params[:status]
      query = query.where(priority: params[:priority]) if params[:priority]
      query = query.where(:labels.in => params[:labels]) if params[:labels]
      
      # 검색어
      if params[:search].present?
        query = query.or(
          { title: /#{params[:search]}/i },
          { description: /#{params[:search]}/i },
          { task_id: params[:search] }
        )
      end
      
      # 정렬
      case params[:sort_by]
      when 'priority'
        query = query.order_by(priority: :desc, created_at: :desc)
      when 'due_date'
        query = query.order_by(due_date: :asc)
      when 'story_points'
        query = query.order_by(story_points: :desc)
      else
        query = query.order_by(created_at: :desc)
      end
      
      # 페이지네이션
      page = params[:page] || 1
      per_page = params[:per_page] || 20
      
      query.skip((page - 1) * per_page).limit(per_page)
    end
    
    def get_task_metrics(task_id)
      task = Mongodb::MongoTask.find(task_id)
      
      {
        task_id: task.task_id,
        cycle_time: task.cycle_time,
        lead_time: task.lead_time,
        time_in_status: task.time_in_status,
        reopen_count: task.reopen_count,
        review_cycles: task.review_cycles,
        comment_count: task.comment_count,
        status_changes: task.status_changes.count,
        completion_percentage: task.completion_percentage
      }
    end
    
    private
    
    def generate_task_id(service_id)
      Mongodb::MongoTask.generate_task_id(service_id)
    end
    
    def get_assignee_name(assignee_id)
      return nil unless assignee_id
      User.find_by(id: assignee_id)&.name
    end
    
    def get_user_name(user_id)
      return nil unless user_id
      User.find_by(id: user_id)&.name || 'Unknown User'
    end
    
    def extract_mentions(content)
      return [] unless content
      # UUID 형식의 멘션 추출
      content.scan(/@user_([a-f0-9\-]{36})/).flatten.uniq
    end
    
    def log_task_activity(task, action, changes = {})
      Mongodb::MongoActivity.log_task_activity(task, action, changes)
    end
    
    # 알림 메서드들
    def notify_assignee(task, assignee_id)
      # TODO: 알림 시스템 구현
      Rails.logger.info "Notifying assignee #{assignee_id} about task #{task.task_id}"
    end
    
    def notify_mentioned_users(comment)
      comment.mentioned_user_ids.each do |user_id|
        # TODO: 알림 시스템 구현
        Rails.logger.info "Notifying user #{user_id} about mention in comment"
      end
    end
    
    def notify_task_blocked(task)
      # TODO: 알림 시스템 구현
      Rails.logger.info "Notifying about blocked task #{task.task_id}"
    end
    
    # Broadcast methods are now delegated to Broadcastable module
  end
end