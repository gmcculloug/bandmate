require_relative '../spec_helper'

RSpec.describe 'Authentication', type: :request do
  describe 'GET /login' do
    it 'displays the login form' do
      get '/login'
      expect(last_response).to be_ok
      expect(last_response.body).to include('Login to Bandage')
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
      expect(last_response.body).to include('Sign Up for Bandage')
      expect(last_response.body).to include('Username:')
      expect(last_response.body).to include('Password:')
    end
  end

  describe 'POST /signup' do
    it 'creates a new user with valid data' do
      expect {
        post '/signup', username: 'newuser', password: 'password123'
      }.to change(User, :count).by(1)
      
      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/')
    end

    it 'rejects invalid data' do
      post '/signup', username: '', password: '123'
      expect(last_response).to be_ok
      expect(last_response.body).to include('can\'t be blank')
    end
  end

  describe 'GET /logout' do
    it 'logs out the user' do
      user = User.create!(username: 'testuser', password: 'password123')
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
end