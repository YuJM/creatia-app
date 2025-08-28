# frozen_string_literal: true

# GitHub Webhook을 처리하는 컨트롤러
class Webhooks::GithubController < ApplicationController
  include Dry::Monads[:result]
  
  # Webhook은 인증 없이 접근 가능
  skip_before_action :authenticate_user!
  skip_before_action :ensure_organization_access
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  
  # CSRF 토큰 검증 제외 (GitHub webhook은 서명으로 검증)
  skip_before_action :verify_authenticity_token
  
  before_action :verify_github_signature
  before_action :set_github_event_type
  
  # POST /webhooks/github
  def create
    case @event_type
    when 'push'
      handle_push_event
    when 'pull_request'
      handle_pull_request_event
    when 'issues'
      handle_issues_event
    when 'ping'
      handle_ping_event
    else
      handle_unsupported_event
    end
  end
  
  private
  
  # GitHub 서명 검증
  def verify_github_signature
    payload_body = request.body.read
    signature = request.headers['X-Hub-Signature-256']
    
    unless signature
      SecurityAuditService.log_security_event(:invalid_request, {
        event_type: 'missing_webhook_signature',
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        risk_level: :high
      })
      
      return render json: { error: 'Missing signature' }, status: :unauthorized
    end
    
    expected_signature = calculate_signature(payload_body)
    
    unless Rack::Utils.secure_compare(signature, expected_signature)
      SecurityAuditService.log_security_event(:unauthorized_access, {
        event_type: 'invalid_webhook_signature',
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        signature_provided: signature,
        risk_level: :critical
      })
      
      return render json: { error: 'Invalid signature' }, status: :unauthorized
    end
    
    # 서명이 유효하면 body를 다시 읽을 수 있도록 재설정
    request.body.rewind
  end
  
  # GitHub 이벤트 타입 설정
  def set_github_event_type
    @event_type = request.headers['X-GitHub-Event']
    
    unless @event_type
      return render json: { error: 'Missing event type' }, status: :bad_request
    end
  end
  
  # Push 이벤트 처리
  def handle_push_event
    contract = GithubWebhookContract.new
    result = contract.call(webhook_params)
    
    case result
    in Success()
      validated_data = result.to_h
      
      # Task ID 추출
      task_id = extract_task_id(validated_data)
      
      if task_id
        process_task_update(task_id, validated_data)
      else
        Rails.logger.info "GitHub Push: Task ID를 찾을 수 없음 - #{validated_data[:ref]}"
      end
      
      # 보안 감사 로그
      SecurityAuditService.log_security_event(:sensitive_data_access, {
        event_type: 'github_webhook_push',
        repository: validated_data.dig(:repository, :full_name),
        branch: validated_data[:ref],
        commits_count: validated_data[:commits]&.size || 0,
        task_id: task_id,
        ip_address: request.remote_ip,
        risk_level: :low
      })
      
      render json: { message: 'Push event processed successfully' }, status: :ok
      
    in Failure()
      Rails.logger.warn "GitHub Webhook 검증 실패: #{result.errors.to_h}"
      
      SecurityAuditService.log_security_event(:invalid_request, {
        event_type: 'github_webhook_validation_failed',
        errors: result.errors.to_h,
        ip_address: request.remote_ip,
        risk_level: :medium
      })
      
      render json: { 
        error: 'Webhook validation failed', 
        details: result.errors.to_h 
      }, status: :unprocessable_entity
    end
  end
  
  # Pull Request 이벤트 처리
  def handle_pull_request_event
    pr_data = webhook_params
    task_id = extract_task_id_from_pr(pr_data)
    
    if task_id
      Rails.logger.info "GitHub PR: Task #{task_id} - #{pr_data.dig(:action)}"
      # 향후 PR 관련 로직 구현
    end
    
    render json: { message: 'Pull request event received' }, status: :ok
  end
  
  # Issues 이벤트 처리
  def handle_issues_event
    render json: { message: 'Issues event received' }, status: :ok
  end
  
  # Ping 이벤트 처리 (웹훅 테스트)
  def handle_ping_event
    Rails.logger.info "GitHub Webhook Ping 수신: #{webhook_params[:zen]}"
    render json: { message: 'pong' }, status: :ok
  end
  
  # 지원하지 않는 이벤트 처리
  def handle_unsupported_event
    Rails.logger.info "지원하지 않는 GitHub 이벤트: #{@event_type}"
    render json: { message: "Event type '#{@event_type}' is not supported" }, status: :ok
  end
  
  # Task ID 추출
  def extract_task_id(webhook_data)
    # 브랜치명에서 Task ID 추출
    ref = webhook_data[:ref]
    branch_name = ref.gsub('refs/heads/', '')
    
    # 브랜치명에서 추출
    branch_match = branch_name.match(/([A-Z]+-\d+)/)
    return branch_match[1] if branch_match
    
    # 커밋 메시지에서 추출
    commits = webhook_data[:commits] || []
    commits.each do |commit|
      message_match = commit[:message].match(/\[?([A-Z]+-\d+)\]?/)
      return message_match[1] if message_match
    end
    
    nil
  end
  
  # Pull Request에서 Task ID 추출
  def extract_task_id_from_pr(pr_data)
    # PR 제목이나 브랜치명에서 Task ID 추출
    title = pr_data.dig(:pull_request, :title) || ''
    branch = pr_data.dig(:pull_request, :head, :ref) || ''
    
    [title, branch].each do |text|
      match = text.match(/([A-Z]+-\d+)/)
      return match[1] if match
    end
    
    nil
  end
  
  # Task 업데이트 처리
  def process_task_update(task_id, webhook_data)
    task = Task.find_by(task_id: task_id)
    
    unless task
      Rails.logger.warn "Task를 찾을 수 없음: #{task_id}"
      return
    end
    
    # 간단한 상태 업데이트 로직
    if task.state == 'todo' && webhook_data[:commits]&.any?
      begin
        task.update!(state: 'in_progress')
        Rails.logger.info "Task #{task_id} 상태를 'in_progress'로 업데이트"
      rescue => e
        Rails.logger.error "Task 업데이트 실패: #{e.message}"
      end
    end
    
    # GitHub 이벤트 기록 (향후 구현)
    # task.github_events.create!(...)
  end
  
  # 서명 계산
  def calculate_signature(payload_body)
    secret = ENV['GITHUB_WEBHOOK_SECRET']
    return nil unless secret
    
    "sha256=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret, payload_body)}"
  end
  
  # Webhook 파라미터 정리
  def webhook_params
    @webhook_params ||= JSON.parse(request.body.read, symbolize_names: true)
  rescue JSON::ParserError => e
    Rails.logger.error "JSON 파싱 오류: #{e.message}"
    {}
  ensure
    request.body.rewind
  end
end
