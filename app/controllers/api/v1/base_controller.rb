# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      include Pundit::Authorization
      
      before_action :authenticate_user!
      before_action :set_default_format
      
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from Pundit::NotAuthorizedError, with: :forbidden
      rescue_from ActionController::ParameterMissing, with: :bad_request
      
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
    end
  end
end