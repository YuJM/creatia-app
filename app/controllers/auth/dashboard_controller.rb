# frozen_string_literal: true

module Auth
  class DashboardController < ApplicationController
    def index
      @organizations = current_user&.organizations || []
    end
  end
end