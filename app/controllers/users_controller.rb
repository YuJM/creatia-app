class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:show, :edit, :update, :destroy]
  
  def index
    @users = policy_scope(User)
    authorize User
    
    respond_to do |format|
      format.html
      format.json { render_serialized(UserSerializer, @users) }
    end
  end

  def show
    authorize @user
    
    respond_to do |format|
      format.html
      format.json { render_serialized(UserSerializer, @user, params: { include_admin_info: true }) }
    end
  end

  def edit
    authorize @user
  end

  def update
    authorize @user
    if @user.update(user_params)
      respond_to do |format|
        format.html { redirect_to @user, notice: 'User was successfully updated.' }
        format.json { render_with_success(UserSerializer, @user) }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render_error(@user.errors) }
      end
    end
  end
  
  def destroy
    authorize @user
    @user.destroy
    redirect_to users_url, notice: 'User was successfully destroyed.'
  end
  
  private
  
  def set_user
    @user = User.find(params[:id])
  end
  
  def user_params
    params.require(:user).permit(*policy(@user).permitted_attributes)
  end
end
