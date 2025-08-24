require 'rails_helper'

RSpec.describe "Devise Routes", type: :request do
  describe "GET /users/sign_up" do
    it "returns success" do
      get "/users/sign_up"
      puts "Response status: #{response.status}"
      puts "Response body: #{response.body[0..500]}"
      expect(response).to have_http_status(:success)
    end
  end
  
  describe "GET /users/sign_in" do
    it "returns success" do
      get "/users/sign_in"
      puts "Response status: #{response.status}"
      puts "Response body: #{response.body[0..500]}"
      expect(response).to have_http_status(:success)
    end
  end
end