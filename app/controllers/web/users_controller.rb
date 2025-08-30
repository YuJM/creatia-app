# frozen_string_literal: true

module Web
  class UsersController < TenantBaseController
    before_action :authenticate_user!
    before_action :set_user, only: [:show, :edit, :update, :destroy]
    load_and_authorize_resource except: [:index]
    
    def index
      @users = User.accessible_by(current_ability)
      authorize! :index, User
      
      respond_to do |format|
        format.html
      end
    end

    def show
      # Already authorized by load_and_authorize_resource
      
      respond_to do |format|
        format.html
      end
    end

    def edit
      # Already authorized by load_and_authorize_resource
    end

    def update
      # Already authorized by load_and_authorize_resource
      if @user.update(user_params)
        respond_to do |format|
          format.html { redirect_to web_user_path(@user), notice: 'User was successfully updated.' }
        end
      else
        respond_to do |format|
          format.html { render :edit, status: :unprocessable_entity }
        end
      end
    end
    
    def destroy
      # Already authorized by load_and_authorize_resource
      @user.destroy
      redirect_to web_users_path, notice: 'User was successfully destroyed.'
    end
    
    private
    
    def set_user
      @user = User.find(params[:id])
    end
    
    def user_params
      # CanCanCan doesn't have permitted_attributes, so we need to define them based on ability
      if can? :manage, @user
        params.require(:user).permit(:email, :username, :name, :bio, :avatar_url, :role)
      else
        params.require(:user).permit(:email, :username, :name, :bio, :avatar_url)
      end
    end
  end
end