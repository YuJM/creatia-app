# frozen_string_literal: true

class Shared::FormSectionComponent < ViewComponent::Base
  def initialize(
    title:,
    description: nil,
    columns: 1,
    border_bottom: true
  )
    @title = title
    @description = description
    @columns = columns
    @border_bottom = border_bottom
  end

  private

  attr_reader :title, :description, :columns, :border_bottom

  def section_classes
    classes = ["px-6 py-6"]
    classes << "border-b border-gray-200" if border_bottom
    classes.join(" ")
  end

  def grid_classes
    case columns
    when 1
      "space-y-4"
    when 2
      "grid grid-cols-1 md:grid-cols-2 gap-4"
    when 3
      "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4"
    when 4
      "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4"
    else
      "space-y-4"
    end
  end
end