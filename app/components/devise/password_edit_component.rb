# frozen_string_literal: true

class Devise::PasswordEditComponent < ViewComponent::Base
  def initialize(resource:, resource_name:, minimum_password_length: nil)
    @resource = resource
    @resource_name = resource_name
    @minimum_password_length = minimum_password_length
  end

  private

  attr_reader :resource, :resource_name, :minimum_password_length

  def devise_mapping
    @devise_mapping ||= Devise.mappings[resource_name]
  end

  def password_path(resource_name)
    send(:"#{resource_name}_password_path")
  end

  def new_session_path(resource_name)
    send(:"new_#{resource_name}_session_path")
  end

  def new_registration_path(resource_name)
    send(:"new_#{resource_name}_registration_path")
  end
end