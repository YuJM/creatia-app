class LogService
  include Singleton
  
  class << self
    delegate :log_activity, :log_error, :log_api_request, to: :instance
  end
  
  def log_activity(controller, action, user = nil, organization = nil, additional_params = {})
    return unless should_log_activity?(controller, action)
    
    ActivityLog.log_activity(
      build_activity_params(controller, action, user, organization, additional_params)
    )
  rescue => e
    Rails.logger.error "LogService#log_activity failed: #{e.message}"
  end
  
  def log_error(exception, controller = nil, user = nil, organization = nil)
    context = build_error_context(controller, user, organization)
    ErrorLog.log_error(exception, context)
  rescue => e
    Rails.logger.error "LogService#log_error failed: #{e.message}"
  end
  
  def log_api_request(request, response, user = nil, organization = nil, additional_params = {})
    return unless should_log_api_request?(request)
    
    ApiRequestLog.log_request(
      build_api_request_params(request, response, user, organization, additional_params)
    )
  rescue => e
    Rails.logger.error "LogService#log_api_request failed: #{e.message}"
  end
  
  private
  
  def should_log_activity?(controller, action)
    # 특정 액션은 로깅하지 않음 (예: health check)
    excluded_actions = %w[up health status]
    excluded_controllers = %w[rails/conductor active_storage]
    
    return false if excluded_actions.include?(action.to_s)
    return false if excluded_controllers.any? { |ec| controller.to_s.include?(ec) }
    
    true
  end
  
  def should_log_api_request?(request)
    # API 요청만 로깅
    request.path.start_with?('/api/') || request.format.json?
  end
  
  def build_activity_params(controller, action, user, organization, additional_params)
    request = controller.request
    
    {
      action: "#{controller.controller_name}##{action}",
      controller: controller.controller_name,
      method: request.method,
      path: request.path,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      status: controller.response.status,
      duration: calculate_duration(controller),
      user_id: user&.id,
      user_email: user&.email,
      organization_id: organization&.id,
      organization_subdomain: organization&.subdomain,
      params: sanitize_params(request.params),
      metadata: additional_params[:metadata],
      data_changes: additional_params[:changes]
    }.compact
  end
  
  def build_error_context(controller, user, organization)
    return {} unless controller
    
    request = controller.request
    
    {
      controller: controller.controller_name,
      action: controller.action_name,
      path: request.path,
      method: request.method,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      referrer: request.referrer,
      user_id: user&.id,
      user_email: user&.email,
      organization_id: organization&.id,
      organization_subdomain: organization&.subdomain,
      params: sanitize_params(request.params),
      session: sanitize_session(controller.session)
    }.compact
  end
  
  def build_api_request_params(request, response, user, organization, additional_params)
    {
      endpoint: extract_endpoint(request.path),
      method: request.method,
      path: request.path,
      query_params: request.query_parameters,
      request_headers: extract_headers(request.headers),
      request_body: sanitize_params(request.params),
      status_code: response.status,
      response_headers: response.headers.to_h,
      response_body: extract_response_body(response, additional_params[:include_response_body]),
      response_time: calculate_response_time(additional_params[:start_time]),
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      api_version: extract_api_version(request),
      client_id: additional_params[:client_id],
      user_id: user&.id,
      organization_id: organization&.id,
      api_key: hash_api_key(additional_params[:api_key]),
      auth_method: additional_params[:auth_method],
      error_message: additional_params[:error_message],
      error_details: additional_params[:error_details],
      metadata: additional_params[:metadata],
      tags: additional_params[:tags]
    }.compact
  end
  
  def calculate_duration(controller)
    return nil unless controller.respond_to?(:view_runtime)
    
    db_runtime = controller.respond_to?(:db_runtime) ? controller.db_runtime : 0
    view_runtime = controller.view_runtime || 0
    
    (db_runtime + view_runtime).round(2)
  end
  
  def calculate_response_time(start_time)
    return nil unless start_time
    
    ((Time.current - start_time) * 1000).round(2) # Convert to milliseconds
  end
  
  def extract_endpoint(path)
    # Extract endpoint pattern from path (e.g., /api/v1/users/123 -> /api/v1/users/:id)
    path.gsub(/\/\d+/, '/:id').gsub(/\/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/, '/:uuid')
  end
  
  def extract_api_version(request)
    # Extract API version from path or header
    if request.path =~ /\/api\/v(\d+)/
      "v#{$1}"
    elsif request.headers['API-Version']
      request.headers['API-Version']
    else
      'v1'
    end
  end
  
  def extract_headers(headers)
    # Extract relevant headers
    relevant_headers = %w[
      Content-Type Accept Accept-Language 
      X-Request-ID X-Forwarded-For
    ]
    
    headers.to_h.select { |k, _| relevant_headers.include?(k) }
  end
  
  def extract_response_body(response, include_body = false)
    return nil unless include_body
    return nil unless response.body.present?
    
    # Only include response body for specific content types and sizes
    content_type = response.headers['Content-Type']
    return nil unless content_type&.include?('application/json')
    return nil if response.body.size > 10_000 # Skip large responses
    
    begin
      JSON.parse(response.body)
    rescue
      nil
    end
  end
  
  def hash_api_key(api_key)
    return nil unless api_key.present?
    
    # Store only a hash of the API key for security
    Digest::SHA256.hexdigest(api_key)
  end
  
  def sanitize_params(params)
    return {} unless params.present?
    
    # Remove sensitive parameters
    filtered = params.except(
      :password, :password_confirmation,
      :token, :secret, :api_key,
      :credit_card, :ssn,
      :authenticity_token, :utf8
    )
    
    # Convert to plain hash if ActionController::Parameters
    filtered = filtered.to_unsafe_h if filtered.respond_to?(:to_unsafe_h)
    
    filtered
  end
  
  def sanitize_session(session)
    return {} unless session.present?
    
    # Only include non-sensitive session data
    session.to_h.slice('session_id', 'user_return_to', 'flash')
  end
end