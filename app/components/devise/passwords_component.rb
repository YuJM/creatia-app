# frozen_string_literal: true

class Devise::PasswordsComponent < ViewComponent::Base
  def initialize(resource:, resource_name:)
    @resource = resource
    @resource_name = resource_name
  end

  private

  attr_reader :resource, :resource_name

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