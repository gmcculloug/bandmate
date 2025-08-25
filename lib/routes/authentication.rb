require 'sinatra/base'

module Routes
end

class Routes::Authentication < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  end
  
  helpers ApplicationHelpers
  
  # ============================================================================
  # AUTHENTICATION ROUTES
  # ============================================================================
  
  get '/login' do
    erb :login, layout: :layout
  end

  post '/login' do
    user = User.where('LOWER(username) = ?', params[:username].downcase).first
    
    if user && user.authenticate(params[:password])
      session[:user_id] = user.id
      
      # Restore the last selected band if it exists and user still has access to it
      if user.last_selected_band && user.bands.include?(user.last_selected_band)
        session[:band_id] = user.last_selected_band.id
      elsif user.bands.any?
        # If no saved band or user no longer has access, select the first band
        session[:band_id] = user.bands.first.id
      end
      
      redirect '/gigs'
    else
      @error = "Invalid username or password"
      erb :login, layout: :layout
    end
  end

  get '/signup' do
    erb :signup, layout: :layout
  end

  post '/signup' do
    # Validate account creation code
    login_secret = ENV['BANDMATE_ACCT_CREATION_SECRET']
    if login_secret.nil? || login_secret.empty?
      @errors = ["Account creation code not configured. Please contact administrator."]
      return erb :signup, layout: :layout
    end
    
    if params[:login_secret] != login_secret
      @errors = ["Invalid account creation code. Please check your code and try again."]
      return erb :signup, layout: :layout
    end
    
    user = User.new(username: params[:username], password: params[:password], email: params[:email].presence)
    
    if user.save
      session[:user_id] = user.id
      redirect '/gigs'
    else
      @errors = user.errors.full_messages
      erb :signup, layout: :layout
    end
  end

  get '/logout' do
    # Save the current band selection before clearing session
    if logged_in? && current_band
      current_user.update(last_selected_band_id: current_band.id)
    end
    
    session.clear
    redirect '/login'
  end

  # ============================================================================
  # USER PROFILE AND ACCOUNT ROUTES
  # ============================================================================

  get '/profile' do
    require_login
    erb :profile
  end

  put '/profile' do
    require_login
    
    user = current_user
    
    # Update user attributes
    if user.update(params[:user])
      @success = "Profile updated successfully!"
      erb :profile
    else
      @errors = user.errors.full_messages
      erb :profile
    end
  end

  post '/profile/change_password' do
    require_login
    
    user = current_user
    
    # Verify current password
    unless user.authenticate(params[:current_password])
      @errors = ["Current password is incorrect"]
      return erb :profile
    end
    
    # Update password
    if params[:new_password] == params[:confirm_password]
      if user.update(password: params[:new_password])
        @success = "Password changed successfully!"
      else
        @errors = user.errors.full_messages
      end
    else
      @errors = ["New passwords don't match"]
    end
    
    erb :profile
  end

  get '/account/delete' do
    require_login
    erb :delete_account
  end

  post '/account/delete' do
    require_login
    
    # Verify password for security
    unless current_user.authenticate(params[:password])
      @errors = ["Incorrect password. Please try again."]
      return erb :delete_account
    end
    
    user = current_user
    
    begin
      # Clear last selected band reference first
      user.update(last_selected_band_id: nil)
      
      # Handle bands owned by this user
      owned_bands = Band.where(owner: user)
      owned_bands.each do |band|
        # If band has other members, transfer ownership to the first member
        other_members = band.users.where.not(id: user.id)
        if other_members.any?
          band.update(owner: other_members.first)
        else
          # If no other members, delete the band
          # First clear all user associations
          band.users.clear
          band.destroy
        end
      end
      
      # Remove user from all bands
      user.bands.clear
      
      # Clear session before deleting user
      session.clear
      
      # Delete the user
      user.destroy
      
      redirect '/login?account_deleted=true'
    rescue => e
      # If something goes wrong, restore the session
      session[:user_id] = user.id
      @errors = ["Failed to delete account. Please try again or contact support."]
      erb :delete_account
    end
  end
end