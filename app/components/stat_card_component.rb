# frozen_string_literal: true

class StatCardComponent < ViewComponent::Base
  def initialize(title:, value:, color: "blue", link: nil, link_text: nil, icon: nil)
    @title = title
    @value = value
    @color = color
    @link = link
    @link_text = link_text
    @icon = icon
  end

  private

  attr_reader :title, :value, :color, :link, :link_text, :icon

  def value_class
    "text-3xl font-bold text-#{color}-600"
  end
end