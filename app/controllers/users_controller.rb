class UsersController < ApplicationController
  def index
    @users=User.all
  end
  
  def new
    @user=User.new
  end
  
  def create
    @user = User.new(params[:user])
    if @user.save
      flash[:notice]="Successfully Created User"
      if params[:user][:avatar].blank?
        redirect_to user_url(@user)
      else
        render :action => "crop"
      end
    else
      render :action => "new"
    end
  end
  
  def show
    @user=User.find(params[:id])
  end
  
  def edit
    @user=User.find(params[:id])
  end
  
  def update
    @user=User.find(params[:id])
    if @user.update_attributes(params[:user])
      flash[:notice]="Successfully Updated User"
      if params[:user][:avatar].blank?
        redirect_to user_url(@user)
      else
        render :action => "crop"
      end
    else
      render :action => "edit"
    end
  end
  
  def destroy
    User.find(params[:id]).destroy
    flash[:notice] = "User deleted."
    redirect_to users_url
  end
end
