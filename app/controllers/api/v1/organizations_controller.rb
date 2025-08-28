# frozen_string_literal: true

module Api
  module V1
    class OrganizationsController < BaseController
      skip_before_action :authenticate_user!, only: [:index]
      
      def index
        render_error('Unauthorized', status: :unauthorized)
      end
      
      def show
        organization = Organization.find(params[:id])
        render_serialized(OrganizationSerializer, organization)
      end
      
      def create
        organization = Organization.new(organization_params)
        
        if organization.save
          render_serialized(OrganizationSerializer, organization, status: :created)
        else
          render_error(organization.errors)
        end
      end
      
      def update
        organization = Organization.find(params[:id])
        
        if organization.update(organization_params)
          render_serialized(OrganizationSerializer, organization)
        else
          render_error(organization.errors)
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