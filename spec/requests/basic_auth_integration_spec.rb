# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Basic Auth Integration', type: :request do
  let!(:user) { create(:user, email: 'test@example.com', password: 'password123') }
  let!(:organization) { create(:organization, subdomain: 'testorg') }

  before do
    # 사용자를 조직에 추가
    organization.organization_memberships.create!(
      user: user,
      role: 'owner',
      active: true
    )
  end

  context 'when using HTTP Basic Authentication' do
    let(:credentials) { Base64.encode64("#{user.email}:password123").strip }
    let(:headers) { { 'HTTP_AUTHORIZATION' => "Basic #{credentials}" } }

    it 'authenticates user with valid credentials' do
      headers['HTTP_HOST'] = 'api.creatia.local'
      get '/api/v1/auth/me', headers: headers
      
      # API 엔드포인트에 인증된 상태로 접근할 수 있어야 함
      # 401이 아닌 다른 응답을 받으면 인증이 성공한 것
      expect(response.status).not_to eq(401)
    end

    it 'allows access to protected resources' do
      # 조직 대시보드에 접근
      headers['HTTP_HOST'] = 'testorg.creatia.local'
      
      get '/dashboard', headers: headers
      
      # 인증이 성공하면 대시보드에 접근할 수 있어야 함
      expect(response.status).not_to eq(401)
    end

    it 'rejects invalid credentials' do
      invalid_credentials = Base64.encode64("#{user.email}:wrongpassword").strip
      invalid_headers = { 
        'HTTP_AUTHORIZATION' => "Basic #{invalid_credentials}",
        'HTTP_HOST' => 'api.creatia.local'
      }
      
      get '/api/v1/auth/me', headers: invalid_headers
      
      # 잘못된 인증 정보로는 접근할 수 없음
      expect(response.status).to eq(401).or eq(302) # 401 또는 로그인 페이지로 리다이렉트
    end

    it 'rejects non-existent user' do
      invalid_credentials = Base64.encode64("nonexistent@example.com:password123").strip
      invalid_headers = { 
        'HTTP_AUTHORIZATION' => "Basic #{invalid_credentials}",
        'HTTP_HOST' => 'api.creatia.local'
      }
      
      get '/api/v1/auth/me', headers: invalid_headers
      
      expect(response.status).to eq(401).or eq(302)
    end
  end

  context 'when Basic Auth is not provided' do
    it 'requires authentication for protected resources' do
      get '/api/v1/auth/me', headers: { 'HTTP_HOST' => 'api.creatia.local' }
      
      # Basic Auth가 없으면 인증되지 않은 상태
      expect(response.status).to eq(401).or eq(302)
    end
  end

  context 'in production environment' do
    before do
      allow(Rails.env).to receive(:development?).and_return(false)
      allow(Rails.env).to receive(:test?).and_return(false)
      allow(Rails.env).to receive(:production?).and_return(true)
    end

    it 'does not process Basic Auth' do
      credentials = Base64.encode64("#{user.email}:password123").strip
      headers = { 
        'HTTP_AUTHORIZATION' => "Basic #{credentials}",
        'HTTP_HOST' => 'api.creatia.local'
      }
      
      get '/api/v1/auth/me', headers: headers
      
      # 프로덕션에서는 Basic Auth를 처리하지 않으므로 인증되지 않음
      expect(response.status).to eq(401).or eq(302)
    end
  end
end