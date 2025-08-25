class ApplicationController < ActionController::Base
  include Pundit::Authorization
  
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # Pundit authorization check - don't run on Devise or system controllers
  after_action :verify_authorized, unless: :skip_pundit?
  after_action :verify_policy_scoped, unless: :skip_pundit?, if: -> { action_name == 'index' }
  
  # Pundit exception handling
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  
  private
  
  # Alba JSON Serialization 헬퍼 메서드들
  
  # 기본적인 직렬화를 수행합니다.
  # @param serializer_class [Class] 사용할 Serializer 클래스
  # @param object [Object] 직렬화할 객체 (단일 객체 또는 컬렉션)
  # @param options [Hash] 추가 옵션 (status, params 등)
  def render_serialized(serializer_class, object, options = {})
    params_hash = options[:params] || {}
    
    # 시간 헬퍼를 자동으로 전달
    params_hash[:time_helper] = helpers unless params_hash.key?(:time_helper)
    
    render json: serializer_class.new(object, params: params_hash).serializable_hash, 
           status: options[:status] || :ok
  end
  
  # 성공 응답 형태로 래핑하여 직렬화합니다.
  # @param serializer_class [Class] 사용할 Serializer 클래스
  # @param object [Object] 직렬화할 객체
  # @param options [Hash] 추가 옵션
  def render_with_success(serializer_class, object, options = {})
    params_hash = options[:params] || {}
    params_hash[:time_helper] = helpers unless params_hash.key?(:time_helper)
    
    render json: {
      success: true,
      data: serializer_class.new(object, params: params_hash).serializable_hash
    }, status: options[:status] || :ok
  end
  
  # 에러 응답을 표준화된 형태로 반환합니다.
  # @param errors [ActiveModel::Errors, String, Array] 에러 데이터
  # @param options [Hash] 추가 옵션 (status, single_error 등)
  def render_error(errors, options = {})
    error_data = {
      success: false,
      errors: errors
    }
    
    # 단일 에러 메시지가 지정된 경우 우선 사용
    if options[:single_error]
      error_data[:errors] = options[:single_error]
    end
    
    render json: ErrorSerializer.new(error_data).serializable_hash,
           status: options[:status] || :unprocessable_entity
  end
  
  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_to(request.referrer || root_path)
  end
  
  def skip_pundit?
    devise_controller? || 
    params[:controller] =~ /(^(rails_)?admin)|(^pages$)/ || 
    params[:controller] == 'users/omniauth_callbacks' ||
    params[:controller] =~ /^devise/
  end
end
