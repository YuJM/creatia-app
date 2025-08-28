# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BasicAuthMiddleware do
  let(:app) { double('app') }
  let(:middleware) { BasicAuthMiddleware.new(app) }
  let(:user) { create(:user, email: 'test@example.com', password: 'password123') }
  
  before do
    allow(app).to receive(:call).and_return([200, {}, ['OK']])
  end

  describe '#call' do
    context 'in development environment' do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
        allow(Rails.env).to receive(:test?).and_return(false)
      end

      it 'processes basic auth when Authorization header is present' do
        auth_string = Base64.encode64("#{user.email}:password123").strip
        env = {
          'HTTP_AUTHORIZATION' => "Basic #{auth_string}",
          'warden' => double('warden'),
          'rack.session' => {}
        }
        
        expect(env['warden']).to receive(:set_user).with(user, scope: :user)
        
        middleware.call(env)
        
        expect(app).to have_received(:call).with(env)
      end

      it 'handles invalid credentials gracefully' do
        auth_string = Base64.encode64("#{user.email}:wrongpassword").strip
        env = {
          'HTTP_AUTHORIZATION' => "Basic #{auth_string}",
          'warden' => double('warden'),
          'rack.session' => {}
        }
        
        expect(env['warden']).not_to receive(:set_user)
        
        middleware.call(env)
        
        expect(app).to have_received(:call).with(env)
      end

      it 'handles non-existent user gracefully' do
        auth_string = Base64.encode64("nonexistent@example.com:password123").strip
        env = {
          'HTTP_AUTHORIZATION' => "Basic #{auth_string}",
          'warden' => double('warden'),
          'rack.session' => {}
        }
        
        expect(env['warden']).not_to receive(:set_user)
        
        middleware.call(env)
        
        expect(app).to have_received(:call).with(env)
      end

      it 'passes through when no Authorization header' do
        env = {}
        
        middleware.call(env)
        
        expect(app).to have_received(:call).with(env)
      end

      it 'passes through when Authorization is not Basic' do
        env = {
          'HTTP_AUTHORIZATION' => 'Bearer token123'
        }
        
        middleware.call(env)
        
        expect(app).to have_received(:call).with(env)
      end
    end

    context 'in test environment' do
      before do
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(Rails.env).to receive(:test?).and_return(true)
      end

      it 'processes basic auth' do
        auth_string = Base64.encode64("#{user.email}:password123").strip
        env = {
          'HTTP_AUTHORIZATION' => "Basic #{auth_string}",
          'warden' => double('warden'),
          'rack.session' => {}
        }
        
        expect(env['warden']).to receive(:set_user).with(user, scope: :user)
        
        middleware.call(env)
      end
    end

    context 'in production environment' do
      before do
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(Rails.env).to receive(:test?).and_return(false)
        allow(Rails.env).to receive(:production?).and_return(true)
      end

      it 'does not process basic auth' do
        auth_string = Base64.encode64("#{user.email}:password123").strip
        env = {
          'HTTP_AUTHORIZATION' => "Basic #{auth_string}",
          'warden' => double('warden'),
          'rack.session' => {}
        }
        
        expect(env['warden']).not_to receive(:set_user)
        
        middleware.call(env)
        
        expect(app).to have_received(:call).with(env)
      end
    end
  end

  describe 'error handling' do
    before do
      allow(Rails.env).to receive(:development?).and_return(true)
    end

    it 'handles malformed base64' do
      env = {
        'HTTP_AUTHORIZATION' => 'Basic malformed_base64',
        'warden' => double('warden'),
        'rack.session' => {}
      }
      
      expect { middleware.call(env) }.not_to raise_error
      expect(app).to have_received(:call).with(env)
    end

    it 'handles missing colon in credentials' do
      auth_string = Base64.encode64("no_colon_here").strip
      env = {
        'HTTP_AUTHORIZATION' => "Basic #{auth_string}",
        'warden' => double('warden'),
        'rack.session' => {}
      }
      
      expect { middleware.call(env) }.not_to raise_error
      expect(app).to have_received(:call).with(env)
    end
  end
end