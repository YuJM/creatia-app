# frozen_string_literal: true

module Milestones
  class MilestoneFormComponent < ViewComponent::Base
    include Turbo::FramesHelper

    def initialize(milestone:, organization:, current_user:, form_url: nil, form_method: :post)
      @milestone = milestone
      @organization = organization
      @current_user = current_user
      @form_url = form_url
      @form_method = form_method
    end

    private

    attr_reader :milestone, :organization, :current_user, :form_url, :form_method

    def form_title
      milestone.persisted? ? "Edit Milestone" : "New Milestone"
    end

    def submit_button_text
      milestone.persisted? ? "Update Milestone" : "Create Milestone"
    end

    def available_users
      @available_users ||= organization.users.active
    end

    def available_teams
      @available_teams ||= organization.teams
    end

    def milestone_types
      [
        ["Release", "release"],
        ["Feature", "feature"],
        ["Business", "business"]
      ]
    end

    def milestone_statuses
      [
        ["Planning", "planning"],
        ["Active", "active"],
        ["Completed", "completed"],
        ["Cancelled", "cancelled"]
      ]
    end
  end
end