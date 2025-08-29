class LandingController < ApplicationController
  layout 'public'
  skip_before_action :authenticate_user!, if: -> { defined?(authenticate_user!) }
  
  def index
    redirect_to root_path if user_signed_in?
  end
end
