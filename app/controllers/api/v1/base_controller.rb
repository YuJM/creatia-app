# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      include Pundit::Authorization
      
      before_action :authenticate_user!
      before_action :set_default_format
      before_action :start_api_timer
      after_action :log_api_request
      
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from Pundit::NotAuthorizedError, with: :forbidden
      rescue_from ActionController::ParameterMissing, with: :bad_request
      rescue_from StandardError, with: :internal_server_error
      
      private
      
      def set_default_format
        request.format = :json
      end
      
      def authenticate_user!
        if request.headers['Authorization'].present?
          authenticate_with_token
        else
          render_unauthorized
        end
      end
      
      def authenticate_with_token
        token = request.headers['Authorization'].split(' ').last
        # TODO: Implement proper JWT or token authentication
        render_unauthorized
      end
      
      def render_unauthorized
        render json: { error: 'Unauthorized' }, status: :unauthorized
      end
      
      def not_found
        render json: { error: 'Not found' }, status: :not_found
      end
      
      def forbidden
        render json: { error: 'Forbidden' }, status: :forbidden
      end
      
      def bad_request(exception)
        render json: { error: exception.message }, status: :bad_request
      end
      
      def internal_server_error(exception)
        # 에러 로깅
        LogService.log_error(exception, self, current_user, current_organization)
        
        # 프로덕션에서는 상세 에러 숨기기
        if Rails.env.production?
          render json: { error: 'Internal server error' }, status: :internal_server_error
        else
          render json: { 
            error: exception.message,
            backtrace: exception.backtrace.first(5)
          }, status: :internal_server_error
        end
      end
      
      def current_user
        @current_user
      end
      
      def current_organization
        # API의 경우 헤더나 파라미터로 조직 식별
        @current_organization ||= begin
          if params[:organization_id].present?
            ::Organization.find(params[:organization_id])
          elsif request.headers['X-Organization-ID'].present?
            ::Organization.find(request.headers['X-Organization-ID'])
          end
        end
      end
      
      def start_api_timer
        @api_start_time = Time.current
      end
      
      def log_api_request
        LogService.log_api_request(
          request,
          response,
          current_user,
          current_organization,
          start_time: @api_start_time,
          auth_method: @auth_method,
          client_id: @client_id,
          api_key: @api_key,
          include_response_body: Rails.env.development?
        )
      end
    end
  end
end