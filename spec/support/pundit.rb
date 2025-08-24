# Pundit test helpers configuration
RSpec.configure do |config|
  config.include Pundit::Matchers, type: :policy
  
  # Mock Pundit authorization in controller tests
  config.before(:each, type: :controller) do
    # Skip Pundit authorization for controller tests by default
    # Enable it explicitly in specs that need to test authorization
    allow(controller).to receive(:verify_authorized).and_return(true)
    allow(controller).to receive(:verify_policy_scoped).and_return(true)
  end
end

# Helper methods for Pundit testing
module PunditSpecHelper
  def enable_pundit_authorization!
    allow(controller).to receive(:verify_authorized).and_call_original
    allow(controller).to receive(:verify_policy_scoped).and_call_original
  end
  
  def mock_policy(user, record, policy_class, permissions = {})
    policy = instance_double(policy_class)
    
    permissions.each do |action, result|
      allow(policy).to receive("#{action}?").and_return(result)
    end
    
    allow(policy_class).to receive(:new).with(user, record).and_return(policy)
    policy
  end
  
  def expect_to_authorize(action, record)
    expect(controller).to receive(:authorize).with(record, action)
  end
  
  def expect_to_policy_scope(scope)
    expect(controller).to receive(:policy_scope).with(scope).and_call_original
  end
end

RSpec.configure do |config|
  config.include PunditSpecHelper, type: :controller
end