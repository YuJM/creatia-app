# Shared examples for authentication testing
RSpec.shared_examples "requires authentication" do |action, method = :get, params = {}|
  context "when not authenticated" do
    before { sign_out :user if defined?(current_user) }
    
    it "redirects to login page" do
      send(method, action, params: params)
      expect(response).to redirect_to(new_user_session_path)
    end
    
    it "sets flash message" do
      send(method, action, params: params)
      expect(flash[:alert]).to eq("You need to sign in or sign up before continuing.")
    end
  end
end

RSpec.shared_examples "requires admin" do |action, method = :get, params = {}|
  context "when user is not admin" do
    let(:user) { create(:user, role: 'user') }
    
    before { sign_in user }
    
    it "raises not authorized error" do
      expect {
        send(method, action, params: params)
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end
  
  context "when user is admin" do
    let(:admin) { create(:user, :admin) }
    
    before { sign_in admin }
    
    it "allows access" do
      send(method, action, params: params)
      expect(response).to be_successful
    end
  end
end

RSpec.shared_examples "requires authorization" do |action, method = :get, params = {}|
  context "authorization checks" do
    let(:user) { create(:user) }
    
    before do
      sign_in user
      enable_pundit_authorization!
    end
    
    it "verifies authorization" do
      expect(controller).to receive(:authorize)
      send(method, action, params: params)
    end
  end
end