require_relative '../spec_helper'

RSpec.describe 'Authentication', type: :request do
  describe 'GET /login' do
    it 'displays the login form' do
      get '/login'
      expect(last_response).to be_ok
      expect(last_response.body).to include('Login to Bandmate')
      expect(last_response.body).to include('Username:')
      expect(last_response.body).to include('Password:')
    end
  end

  describe 'POST /login' do
    let!(:user) { User.create!(username: 'testuser', password: 'password123') }

    it 'logs in with valid credentials' do
      post '/login', username: 'testuser', password: 'password123'
      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/')
    end

    it 'rejects invalid credentials' do
      post '/login', username: 'testuser', password: 'wrongpassword'
      expect(last_response).to be_ok
      expect(last_response.body).to include('Invalid username or password')
    end
  end

  describe 'GET /signup' do
    it 'displays the signup form' do
      get '/signup'
      expect(last_response).to be_ok
      expect(last_response.body).to include('Sign Up for Bandmate')
      expect(last_response.body).to include('Username:')
      expect(last_response.body).to include('Password:')
      expect(last_response.body).to include('Email Address (Optional):')
      expect(last_response.body).to include('Login Secret:')
    end
  end

  describe 'POST /signup' do
    before do
      ENV['BANDMATE_LOGIN_SECRET'] = 'test_secret_123'
    end

    after do
      ENV.delete('BANDMATE_LOGIN_SECRET')
    end

    it 'creates a new user with valid data and correct login secret' do
      expect {
        post '/signup', username: 'newuser', password: 'password123', email: 'test@example.com', login_secret: 'test_secret_123'
      }.to change(User, :count).by(1)
      
      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/')
    end

    it 'rejects signup with incorrect login secret' do
      expect {
        post '/signup', username: 'newuser', password: 'password123', email: 'test@example.com', login_secret: 'wrong_secret'
      }.not_to change(User, :count)
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Invalid login secret')
    end

    it 'rejects signup without login secret' do
      expect {
        post '/signup', username: 'newuser', password: 'password123', email: 'test@example.com'
      }.not_to change(User, :count)
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Invalid login secret')
    end

    it 'rejects invalid data' do
      post '/signup', username: '', password: '123', login_secret: 'test_secret_123'
      expect(last_response).to be_ok
      expect(last_response.body).to include('can\'t be blank')
    end

    it 'rejects signup when BANDMATE_LOGIN_SECRET environment variable is not set' do
      ENV.delete('BANDMATE_LOGIN_SECRET')
      
      expect {
        post '/signup', username: 'newuser', password: 'password123', email: 'test@example.com', login_secret: 'any_secret'
      }.not_to change(User, :count)
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Login secret not configured')
    end
  end

  describe 'GET /logout' do
    it 'logs out the user' do
      user = User.create!(username: 'testuser', password: 'password123', email: 'test@example.com')
      post '/login', username: 'testuser', password: 'password123'
      
      get '/logout'
      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/login')
    end
  end

  describe 'protected routes' do
    it 'redirects to login when not authenticated' do
      get '/'
      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/login')
      
      get '/songs'
      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/login')
      
      get '/set_lists'
      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/login')
    end
  end

  describe 'Account deletion' do
    let!(:user) { User.create!(username: 'testuser', password: 'password123', email: 'test@example.com') }
    let!(:band) { Band.create!(name: 'Test Band') }
    let!(:user_band) { UserBand.create!(user: user, band: band) }

    before do
      post '/login', username: 'testuser', password: 'password123'
    end

    describe 'GET /account/delete' do
      it 'displays the delete account form' do
        get '/account/delete'
        expect(last_response).to be_ok
        expect(last_response.body).to include('Delete Account')
        expect(last_response.body).to include('Permanently Delete My Account')
      end
    end

    describe 'POST /account/delete' do
      it 'deletes the account with correct password' do
        post '/account/delete', password: 'password123'
        
        expect(last_response.status).to eq(302)
        expect(last_response.headers['Location']).to include('/login?account_deleted=true')
      end

      it 'rejects deletion with incorrect password' do
        expect {
          post '/account/delete', password: 'wrongpassword'
        }.not_to change(User, :count)
        
        expect(last_response).to be_ok
        expect(last_response.body).to include('Incorrect password')
      end

      it 'rejects deletion without password' do
        expect {
          post '/account/delete', password: ''
        }.not_to change(User, :count)
        
        expect(last_response).to be_ok
        expect(last_response.body).to include('Incorrect password')
      end

      it 'removes user from bands when deleting account' do
        expect {
          post '/account/delete', password: 'password123'
        }.to change(UserBand, :count).by(-1)
        
        expect(last_response.status).to eq(302)
        # Check that the user was actually removed from the band
        band.reload
        expect(band.users).not_to include(user)
      end
    end
  end

  describe 'User Profile' do
    let!(:user) { User.create!(username: 'testuser', password: 'password123', email: 'test@example.com') }

    before do
      post '/login', username: 'testuser', password: 'password123'
    end

    describe 'GET /profile' do
      it 'displays the profile page' do
        get '/profile'
        expect(last_response).to be_ok
        expect(last_response.body).to include('User Profile')
        expect(last_response.body).to include('testuser')
        expect(last_response.body).to include('test@example.com')
      end
    end

    describe 'PUT /profile' do
      it 'updates user email successfully' do
        put '/profile', user: { email: 'newemail@example.com' }
        expect(last_response).to be_ok
        expect(last_response.body).to include('Profile updated successfully!')
        
        user.reload
        expect(user.email).to eq('newemail@example.com')
      end

      it 'rejects invalid email format' do
        put '/profile', user: { email: 'invalid-email' }
        expect(last_response).to be_ok
        expect(last_response.body).to include('Email is invalid')
      end
    end

    describe 'POST /profile/change_password' do
      it 'changes password successfully' do
        post '/profile/change_password', 
          current_password: 'password123',
          new_password: 'newpassword123',
          confirm_password: 'newpassword123'
        
        expect(last_response).to be_ok
        expect(last_response.body).to include('Password changed successfully!')
        
        # Verify new password works
        post '/logout'
        post '/login', username: 'testuser', password: 'newpassword123'
        expect(last_response.status).to eq(302)
        expect(last_response.headers['Location']).to include('/')
      end

      it 'rejects incorrect current password' do
        post '/profile/change_password', 
          current_password: 'wrongpassword',
          new_password: 'newpassword123',
          confirm_password: 'newpassword123'
        
        expect(last_response).to be_ok
        expect(last_response.body).to include('Current password is incorrect')
      end

      it 'rejects mismatched new passwords' do
        post '/profile/change_password', 
          current_password: 'password123',
          new_password: 'newpassword123',
          confirm_password: 'differentpassword'
        
        expect(last_response).to be_ok
        expect(last_response.body).to include('New passwords don\'t match')
      end

      it 'rejects password that is too short' do
        post '/profile/change_password', 
          current_password: 'password123',
          new_password: '123',
          confirm_password: '123'
        
        expect(last_response).to be_ok
        expect(last_response.body).to include('Password is too short')
      end
    end
  end
end