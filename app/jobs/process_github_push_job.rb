# frozen_string_literal: true

require_relative '../models/payloads/github_payload'

class ProcessGithubPushJob < ApplicationJob
  queue_as :default

  def perform(webhook_data)
    payload = GithubPayload.new(webhook_data)
    
    Rails.logger.info "Processing GitHub push webhook: #{payload.to_activity_data.inspect}"
    
    # Task ID 추출
    task_id = payload.task_id
    return unless task_id
    
    # Task 찾기
    # task_id는 PREFIX-UUID 형식일 수도 있고 PREFIX-NUMBER 형식일 수도 있음
    # 모든 Task를 조회하여 task_id가 일치하는 것을 찾음
    task = Task.joins(:service).find { |t| t.task_id == task_id }
    return unless task
    
    # 활동 기록 생성
    record_activity(task, payload)
    
    # 상태 자동 업데이트
    auto_update_task_status(task, payload)
  end
  
  private
  
  def record_activity(task, payload)
    # 나중에 Activity 모델이 있다면 구현
    # task.activities.create!(
    #   action: 'github_push',
    #   metadata: payload.to_activity_data
    # )
    
    Rails.logger.info "Task #{task.task_id}: GitHub push from #{payload.author_name}"
  end
  
  def auto_update_task_status(task, payload)
    # 새 브랜치 생성 시 자동으로 in_progress로 변경
    if payload.is_branch_creation? && task.status == 'todo'
      task.transition_to!('in_progress')
      Rails.logger.info "Task #{task.task_id}: Status changed to in_progress (branch created)"
    end
    
    # PR 관련 키워드가 커밋 메시지에 있으면 review로 변경
    if payload.latest_commit_message&.match?(/\b(PR|pull request|review)\b/i) && task.status == 'in_progress'
      task.transition_to!('review')
      Rails.logger.info "Task #{task.task_id}: Status changed to review (PR keyword detected)"
    end
  end
end