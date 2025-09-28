# frozen_string_literal: true

class Shared::PageHeaderComponent < ViewComponent::Base
  def initialize(
    title:,
    description: nil,
    back_link: nil,
    back_text: "Back",
    actions: []
  )
    @title = title
    @description = description
    @back_link = back_link
    @back_text = back_text
    @actions = actions
  end

  private

  attr_reader :title, :description, :back_link, :back_text, :actions
end