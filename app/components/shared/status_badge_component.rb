# frozen_string_literal: true

class Shared::StatusBadgeComponent < ViewComponent::Base
  def initialize(
    status:,
    size: :default,
    custom_text: nil
  )
    @status = status.to_s.downcase
    @size = size
    @custom_text = custom_text
  end

  private

  attr_reader :status, :size, :custom_text

  def display_text
    custom_text || status.humanize
  end

  def status_classes
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
      "px-2.5 py-0.5 text-xs"
    end
  end

  def color_classes
    case status
    when 'completed', 'success', 'active', 'approved'
      'bg-green-100 text-green-800'
    when 'in_progress', 'active', 'running'
      'bg-blue-100 text-blue-800'
    when 'planning', 'pending', 'draft'
      'bg-gray-100 text-gray-800'
    when 'cancelled', 'failed', 'rejected', 'error'
      'bg-red-100 text-red-800'
    when 'warning', 'at_risk', 'delayed'
      'bg-yellow-100 text-yellow-800'
    when 'on_hold', 'paused'
      'bg-orange-100 text-orange-800'
    when 'archived'
      'bg-gray-100 text-gray-600'
    else
      'bg-gray-100 text-gray-800'
    end
  end
end