# frozen_string_literal: true

class OrganizationCardComponent < ViewComponent::Base
  def initialize(organization:, action_path: nil, action_method: :get)
    @organization = organization
    @action_path = action_path
    @action_method = action_method
  end

  private

  attr_reader :organization, :action_path, :action_method

  def action_text
    if action_path&.include?('/switch')
      "Switch"
    else
      case action_method
      when :post
        "Enter"
      when :delete
        "Remove"
      else
        "View"
      end
    end
  end

  def action_class
    case action_method
    when :post
      "bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
    when :delete
      "bg-red-500 text-white px-4 py-2 rounded hover:bg-red-600"
    else
      "bg-gray-500 text-white px-4 py-2 rounded hover:bg-gray-600"
    end
  end
end