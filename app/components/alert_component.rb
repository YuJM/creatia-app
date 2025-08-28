# frozen_string_literal: true

class AlertComponent < ViewComponent::Base
  def initialize(type: :info, title: nil, dismissable: false)
    @type = type
    @title = title
    @dismissable = dismissable
  end

  private

  attr_reader :type, :title, :dismissable

  def container_class
    base = "rounded-lg p-4"
    case type
    when :warning
      "#{base} bg-yellow-100"
    when :error
      "#{base} bg-red-100"
    when :success
      "#{base} bg-green-100"
    else
      "#{base} bg-blue-100"
    end
  end

  def text_class
    case type
    when :warning
      "text-yellow-800"
    when :error
      "text-red-800"
    when :success
      "text-green-800"
    else
      "text-blue-800"
    end
  end
end