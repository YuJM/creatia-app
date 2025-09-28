# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrganizationPolicy, type: :policy do
  subject { described_class.new(user, organization) }

  let(:organization) { create(:organization) }

  before do
    ActsAsTenant.current_tenant = organization
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  context "when user is nil (guest)" do
    let(:user) { nil }

    it { is_expected.to forbid_actions([:show, :update, :destroy, :switch, :manage_settings, :manage_members, :manage_billing]) }
    it { is_expected.to forbid_action(:index) }
    it { is_expected.to forbid_action(:create) }
  end

  context "when user is not a member of the organization" do
    let(:user) { create(:user) }

    it { is_expected.to forbid_actions([:show, :update, :destroy, :switch, :manage_settings, :manage_members, :manage_billing]) }
    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:create) }
  end

  context "when user is a viewer of the organization" do
    let(:user) { create(:user) }
    let!(:membership) { create(:organization_membership, :viewer, organization: organization, user: user) }

    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:switch) }
    it { is_expected.to forbid_actions([:update, :destroy, :manage_settings, :manage_members, :manage_billing]) }
  end

  context "when user is a member of the organization" do
    let(:user) { create(:user) }
    let!(:membership) { create(:organization_membership, organization: organization, user: user, role: 'member') }

    it { is_expected.to permit_actions([:index, :show, :create, :switch]) }
    it { is_expected.to forbid_actions([:update, :destroy, :manage_settings, :manage_members, :manage_billing]) }
  end

  context "when user is an admin of the organization" do
    let(:user) { create(:user) }
    let!(:membership) { create(:organization_membership, :admin, organization: organization, user: user) }

    it { is_expected.to permit_actions([:index, :show, :create, :switch, :manage_members]) }
    it { is_expected.to forbid_actions([:update, :destroy, :manage_settings, :manage_billing]) }
  end

  context "when user is the owner of the organization" do
    let(:user) { create(:user) }
    let!(:membership) { create(:organization_membership, :owner, organization: organization, user: user) }

    it { is_expected.to permit_actions([:index, :show, :create, :update, :destroy, :switch, :manage_settings, :manage_members, :manage_billing]) }
  end

  context "when user has inactive membership" do
    let(:user) { create(:user) }
    let!(:membership) { create(:organization_membership, :inactive, organization: organization, user: user, role: 'admin') }

    it { is_expected.to forbid_actions([:show, :update, :destroy, :switch, :manage_settings, :manage_members, :manage_billing]) }
    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:create) }
  end

  describe "Scope" do
    let(:scope) { described_class::Scope.new(user, Organization) }
    
    let!(:org1) { create(:organization) }
    let!(:org2) { create(:organization) }
    let!(:org3) { create(:organization) }
    let!(:inactive_org) { create(:organization, active: false) }

    context "when user is nil" do
      let(:user) { nil }

      it "returns no organizations" do
        expect(scope.resolve).to be_empty
      end
    end

    context "when user has no memberships" do
      let(:user) { create(:user) }

      it "returns no organizations" do
        expect(scope.resolve).to be_empty
      end
    end

    context "when user is a member of one organization" do
      let(:user) { create(:user) }
      let!(:membership) { create(:organization_membership, organization: org1, user: user) }

      it "returns only the organization they belong to" do
        expect(scope.resolve).to contain_exactly(org1)
      end
    end

    context "when user is a member of multiple organizations" do
      let(:user) { create(:user) }
      let!(:membership1) { create(:organization_membership, organization: org1, user: user, role: 'owner') }
      let!(:membership2) { create(:organization_membership, organization: org2, user: user, role: 'member') }
      let!(:membership3) { create(:organization_membership, organization: org3, user: user, role: 'admin') }

      it "returns all organizations they belong to" do
        expect(scope.resolve).to match_array([org1, org2, org3])
      end
    end

    context "when user has inactive memberships" do
      let(:user) { create(:user) }
      let!(:active_membership) { create(:organization_membership, organization: org1, user: user) }
      let!(:inactive_membership) { create(:organization_membership, :inactive, organization: org2, user: user) }

      it "returns only organizations with active memberships" do
        expect(scope.resolve).to contain_exactly(org1)
      end
    end

    context "when organization is inactive" do
      let(:user) { create(:user) }
      let!(:membership) { create(:organization_membership, organization: inactive_org, user: user) }

      it "excludes inactive organizations" do
        expect(scope.resolve).to be_empty
      end
    end
  end

  describe "role-based access details" do
    let(:user) { create(:user) }

    describe "#manage_settings?" do
      context "with different roles" do
        it "allows only owners" do
          membership = create(:organization_membership, :owner, organization: organization, user: user)
          expect(subject.manage_settings?).to be true
        end

        it "denies admins" do
          membership = create(:organization_membership, :admin, organization: organization, user: user)
          expect(subject.manage_settings?).to be false
        end

        it "denies members" do
          membership = create(:organization_membership, organization: organization, user: user, role: 'member')
          expect(subject.manage_settings?).to be false
        end
      end
    end

    describe "#manage_members?" do
      context "with different roles" do
        it "allows owners" do
          membership = create(:organization_membership, :owner, organization: organization, user: user)
          expect(subject.manage_members?).to be true
        end

        it "allows admins" do
          membership = create(:organization_membership, :admin, organization: organization, user: user)
          expect(subject.manage_members?).to be true
        end

        it "denies members" do
          membership = create(:organization_membership, organization: organization, user: user, role: 'member')
          expect(subject.manage_members?).to be false
        end

        it "denies viewers" do
          membership = create(:organization_membership, :viewer, organization: organization, user: user)
          expect(subject.manage_members?).to be false
        end
      end
    end

    describe "#manage_billing?" do
      context "with different roles" do
        it "allows only owners" do
          membership = create(:organization_membership, :owner, organization: organization, user: user)
          expect(subject.manage_billing?).to be true
        end

        it "denies all other roles" do
          ['admin', 'member', 'viewer'].each do |role|
            membership = create(:organization_membership, organization: organization, user: user, role: role)
            expect(subject.manage_billing?).to be false
            membership.destroy
          end
        end
      end
    end
  end
end