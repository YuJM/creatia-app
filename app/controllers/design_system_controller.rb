# frozen_string_literal: true

class DesignSystemController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    # Design system showcase page
  end
end