# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TaskPolicy, type: :policy do
  subject { described_class.new(user, task) }

  let(:organization) { create(:organization) }
  let(:service) { create(:service, organization: organization) }
  let(:task) { create(:task, service: service) }

  before do
    ActsAsTenant.current_tenant = organization
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  context "when user is nil (guest)" do
    let(:user) { nil }

    it { is_expected.to forbid_all_actions }
  end

  context "when user is not a member of the organization" do
    let(:user) { create(:user) }

    it { is_expected.to forbid_all_actions }
  end

  context "when user is a viewer of the organization" do
    let(:user) { create(:user) }
    let!(:membership) { create(:organization_membership, :viewer, organization: organization, user: user) }

    context "with an unassigned task" do
      it { is_expected.to forbid_all_actions }
    end

    context "when assigned to the task" do
      let(:task) { create(:task, service: service, assignee: user) }

      it { is_expected.to permit_action(:show) }
      it { is_expected.to forbid_actions([:create, :update, :destroy, :assign, :complete, :start_pomodoro]) }
    end
  end

  context "when user is a member of the organization" do
    let(:user) { create(:user) }
    let!(:membership) { create(:organization_membership, organization: organization, user: user, role: 'member') }

    context "with an unassigned task" do
      it { is_expected.to forbid_actions([:show, :update, :destroy, :assign, :complete, :start_pomodoro]) }
      it { is_expected.to permit_actions([:index, :create]) }
    end

    context "when assigned to the task" do
      let(:task) { create(:task, service: service, assignee: user) }

      it { is_expected.to permit_actions([:index, :show, :create, :update, :complete, :start_pomodoro]) }
      it { is_expected.to forbid_actions([:destroy, :assign]) }
    end

    context "when creator of the task" do
      let(:task) { create(:task, service: service, created_by: user) }

      it { is_expected.to permit_actions([:index, :show, :create, :update, :destroy, :complete, :assign]) }
      it { is_expected.to forbid_action(:start_pomodoro) }
    end

    context "when team member of the task" do
      let(:team) { create(:team, organization: organization) }
      let(:task) { create(:task, service: service, team: team) }
      
      before do
        # Simulate user being part of the team
        allow(user).to receive(:team_ids).and_return([team.id])
      end

      it { is_expected.to permit_actions([:index, :show, :create]) }
      it { is_expected.to forbid_actions([:update, :destroy, :assign, :complete, :start_pomodoro]) }
    end

    context "when team lead of the task's team" do
      let(:team) { create(:team, organization: organization, lead_id: user.id) }
      let(:task) { create(:task, service: service, team: team) }
      
      before do
        allow(user).to receive(:team_ids).and_return([team.id])
      end

      it { is_expected.to permit_actions([:index, :show, :create, :assign]) }
      it { is_expected.to forbid_actions([:update, :destroy, :complete, :start_pomodoro]) }
    end
  end

  context "when user is an admin of the organization" do
    let(:user) { create(:user) }
    let!(:membership) { create(:organization_membership, :admin, organization: organization, user: user) }

    context "with any task" do
      it { is_expected.to permit_actions([:index, :show, :create, :update, :destroy, :assign]) }
      it { is_expected.to forbid_actions([:complete, :start_pomodoro]) }
    end

    context "when assigned to the task" do
      let(:task) { create(:task, service: service, assignee: user) }

      it { is_expected.to permit_all_actions }
    end

    context "when creator of the task" do
      let(:task) { create(:task, service: service, created_by: user) }

      it { is_expected.to permit_actions([:index, :show, :create, :update, :destroy, :assign, :complete]) }
      it { is_expected.to forbid_action(:start_pomodoro) }
    end
  end

  context "when user is the owner of the organization" do
    let(:user) { create(:user) }
    let!(:membership) { create(:organization_membership, :owner, organization: organization, user: user) }

    context "with any task" do
      it { is_expected.to permit_actions([:index, :show, :create, :update, :destroy, :assign]) }
      it { is_expected.to forbid_actions([:complete, :start_pomodoro]) }
    end

    context "when assigned to the task" do
      let(:task) { create(:task, service: service, assignee: user) }

      it { is_expected.to permit_all_actions }
    end
  end

  describe "Scope" do
    let(:scope) { described_class::Scope.new(user, Task) }
    
    let(:team1) { create(:team, organization: organization) }
    let(:team2) { create(:team, organization: organization) }
    
    let!(:unassigned_task) { create(:task, service: service) }
    let!(:user_assigned_task) { create(:task, service: service, assignee: user) }
    let!(:other_assigned_task) { create(:task, service: service, assignee: create(:user)) }
    let!(:team1_task) { create(:task, service: service, team: team1) }
    let!(:team2_task) { create(:task, service: service, team: team2) }
    
    # Tasks from another organization
    let(:other_org) { create(:organization) }
    let(:other_service) { create(:service, organization: other_org) }
    let!(:other_org_task) do
      ActsAsTenant.with_tenant(other_org) do
        create(:task, service: other_service)
      end
    end

    context "when user is nil" do
      let(:user) { nil }

      it "returns no tasks" do
        expect(scope.resolve).to be_empty
      end
    end

    context "when user is not a member" do
      let(:user) { create(:user) }

      it "returns no tasks" do
        ActsAsTenant.current_tenant = nil
        expect(scope.resolve).to be_empty
      end
    end

    context "when user is a regular member" do
      let(:user) { create(:user) }
      let!(:membership) { create(:organization_membership, organization: organization, user: user, role: 'member') }

      before do
        allow(user).to receive(:team_ids).and_return([team1.id])
      end

      it "returns only tasks assigned to user or in their teams" do
        expect(scope.resolve).to match_array([user_assigned_task, team1_task])
      end

      it "excludes tasks from other organizations" do
        expect(scope.resolve).not_to include(other_org_task)
      end

      it "excludes unassigned tasks not in their teams" do
        expect(scope.resolve).not_to include(unassigned_task)
      end

      it "excludes tasks assigned to others not in their teams" do
        expect(scope.resolve).not_to include(other_assigned_task)
      end
    end

    context "when user is an admin" do
      let(:user) { create(:user) }
      let!(:membership) { create(:organization_membership, :admin, organization: organization, user: user) }

      it "returns all tasks in the organization" do
        expect(scope.resolve).to match_array([unassigned_task, user_assigned_task, other_assigned_task, team1_task, team2_task])
      end

      it "excludes tasks from other organizations" do
        expect(scope.resolve).not_to include(other_org_task)
      end
    end

    context "when user is the owner" do
      let(:user) { create(:user) }
      let!(:membership) { create(:organization_membership, :owner, organization: organization, user: user) }

      it "returns all tasks in the organization" do
        expect(scope.resolve).to match_array([unassigned_task, user_assigned_task, other_assigned_task, team1_task, team2_task])
      end

      it "excludes tasks from other organizations" do
        expect(scope.resolve).not_to include(other_org_task)
      end
    end
  end

  describe "complex permission scenarios" do
    let(:user) { create(:user) }
    let!(:membership) { create(:organization_membership, organization: organization, user: user, role: 'member') }

    describe "task assignment permissions" do
      let(:team) { create(:team, organization: organization) }
      
      context "when user is team lead" do
        let(:team) { create(:team, organization: organization, lead_id: user.id) }
        let(:task) { create(:task, service: service, team: team) }

        before do
          allow(user).to receive(:team_ids).and_return([team.id])
        end

        it "allows assigning tasks within their team" do
          expect(subject.assign?).to be true
        end
      end

      context "when user is not team lead" do
        let(:task) { create(:task, service: service, team: team) }

        before do
          allow(user).to receive(:team_ids).and_return([team.id])
        end

        it "denies assigning tasks" do
          expect(subject.assign?).to be false
        end
      end
    end

    describe "task completion permissions" do
      context "when user is assigned to the task" do
        let(:task) { create(:task, service: service, assignee: user) }

        it "allows completing the task" do
          expect(subject.complete?).to be true
        end

        it "allows starting a pomodoro session" do
          expect(subject.start_pomodoro?).to be true
        end
      end

      context "when user created the task but is not assigned" do
        let(:task) { create(:task, service: service, created_by: user, assignee: create(:user)) }

        it "allows completing the task" do
          expect(subject.complete?).to be true
        end

        it "denies starting a pomodoro session" do
          expect(subject.start_pomodoro?).to be false
        end
      end

      context "when user is admin but not assigned" do
        let!(:membership) { create(:organization_membership, :admin, organization: organization, user: user) }
        let(:task) { create(:task, service: service, assignee: create(:user)) }

        it "denies completing the task" do
          expect(subject.complete?).to be false
        end

        it "denies starting a pomodoro session" do
          expect(subject.start_pomodoro?).to be false
        end
      end
    end
  end
end