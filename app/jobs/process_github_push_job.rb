# frozen_string_literal: true

class ProcessGithubPushJob < ApplicationJob
  queue_as :default

  def perform(webhook_data)
    # 나중에 실제 구현을 추가합니다
    # 여기서는 webhook 데이터를 처리하는 로직을 구현합니다
    Rails.logger.info "Processing GitHub push webhook: #{webhook_data.inspect}"
    
    # Task ID 추출
    task_id = extract_task_id(webhook_data)
    return unless task_id
    
    # Task 찾기 (나중에 구현)
    # task = Task.find_by(task_id: task_id)
    # return unless task
    
    # 상태 업데이트 등의 로직
    # ...
  end
  
  private
  
  def extract_task_id(webhook_data)
    ref = webhook_data[:ref] || webhook_data['ref']
    return nil unless ref
    
    match = ref.match(/([A-Z]+-\d+)/)
    match ? match[1] : nil
  end
end