# frozen_string_literal: true

class Shared::PriorityBadgeComponent < ViewComponent::Base
  def initialize(
    priority:,
    size: :default
  )
    @priority = priority.to_s.downcase
    @size = size
  end

  private

  attr_reader :priority, :size

  def display_text
    priority.titleize
  end

  def priority_classes
    base_classes = size_classes + " " + color_classes
    base_classes
  end

  def size_classes
    case size
    when :small
      "px-2 py-0.5 text-xs"
    when :large
      "px-3 py-1 text-sm"
    else # :default
      "px-2.5 py-1 text-xs"
    end
  end

  def color_classes
    case priority
    when 'urgent', 'critical'
      'bg-red-100 text-red-800'
    when 'high'
      'bg-orange-100 text-orange-800'
    when 'medium', 'normal'
      'bg-yellow-100 text-yellow-800'
    when 'low'
      'bg-green-100 text-green-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end
end