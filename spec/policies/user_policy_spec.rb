require 'rails_helper'

RSpec.describe UserPolicy, type: :policy do
  subject { described_class.new(user, record) }
  
  let(:record) { create(:user) }
  
  context "when user is a guest" do
    let(:user) { nil }
    
    it { is_expected.to forbid_all_actions }
  end
  
  context "when user is the owner" do
    let(:user) { record }
    
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:edit) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to forbid_action(:destroy) } # Users can't delete their own account through policy
    it { is_expected.to forbid_action(:index) }
  end
  
  context "when user is another regular user" do
    let(:user) { create(:user) }
    
    it { is_expected.to permit_action(:show) } # Users can view other profiles
    it { is_expected.to forbid_action(:edit) }
    it { is_expected.to forbid_action(:update) }
    it { is_expected.to forbid_action(:destroy) }
    it { is_expected.to forbid_action(:index) }
  end
  
  context "when user is a moderator" do
    let(:user) { create(:user, :moderator) }
    
    it { is_expected.to permit_action(:show) }
    it { is_expected.to forbid_action(:edit) }
    it { is_expected.to forbid_action(:update) }
    it { is_expected.to forbid_action(:destroy) }
    it { is_expected.to permit_action(:index) }
  end
  
  context "when user is an admin" do
    let(:user) { create(:user, :admin) }
    
    it { is_expected.to permit_actions([:show, :index, :edit, :update, :destroy]) }
    it { is_expected.to forbid_actions([:new, :create]) } # These are handled by Devise
  end
  
  describe "Scope" do
    let(:scope) { described_class::Scope.new(user, User) }
    
    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }
    let!(:admin) { create(:user, :admin) }
    let!(:moderator) { create(:user, :moderator) }
    
    context "when user is nil" do
      let(:user) { nil }
      
      it "returns no users" do
        expect(scope.resolve).to be_empty
      end
    end
    
    context "when user is a regular user" do
      let(:user) { user1 }
      
      it "returns only the current user" do
        expect(scope.resolve).to contain_exactly(user1)
      end
    end
    
    context "when user is a moderator" do
      let(:user) { moderator }
      
      it "returns all users" do
        expect(scope.resolve).to match_array([user1, user2, admin, moderator])
      end
    end
    
    context "when user is an admin" do
      let(:user) { admin }
      
      it "returns all users" do
        expect(scope.resolve).to match_array([user1, user2, admin, moderator])
      end
    end
  end
  
  describe "permitted_attributes" do
    let(:policy) { described_class.new(user, User) }
    
    context "when user is regular user" do
      let(:user) { create(:user) }
      
      it "permits basic attributes" do
        expect(policy.permitted_attributes).to include(:email, :username, :name, :bio, :avatar_url)
      end
      
      it "does not permit role attribute" do
        expect(policy.permitted_attributes).not_to include(:role)
      end
    end
    
    context "when user is admin" do
      let(:user) { create(:user, :admin) }
      
      it "permits all attributes including role" do
        expect(policy.permitted_attributes).to include(:email, :username, :name, :bio, :avatar_url, :role)
      end
    end
  end
end