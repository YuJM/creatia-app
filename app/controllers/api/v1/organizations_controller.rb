# frozen_string_literal: true

module Api
  module V1
    class OrganizationsController < BaseController
      skip_before_action :authenticate_user!, only: [:index]
      
      def index
        render json: { error: 'Unauthorized' }, status: :unauthorized
      end
      
      def show
        organization = Organization.find(params[:id])
        render json: organization
      end
      
      def create
        organization = Organization.new(organization_params)
        
        if organization.save
          render json: organization, status: :created
        else
          render json: { errors: organization.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      def update
        organization = Organization.find(params[:id])
        
        if organization.update(organization_params)
          render json: organization
        else
          render json: { errors: organization.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      def destroy
        organization = Organization.find(params[:id])
        organization.destroy
        head :no_content
      end
      
      private
      
      def organization_params
        params.require(:organization).permit(:name, :subdomain, :description)
      end
    end
  end
end