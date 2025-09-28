# frozen_string_literal: true

class Devise::SessionsComponent < ViewComponent::Base
  def initialize(resource:, resource_name:, return_to: nil)
    @resource = resource
    @resource_name = resource_name
    @return_to = return_to
  end

  private

  attr_reader :resource, :resource_name, :return_to

  def devise_mapping
    @devise_mapping ||= Devise.mappings[resource_name]
  end

  def session_path(resource_name)
    send(:"#{resource_name}_session_path")
  end

  def new_password_path(resource_name)
    send(:"new_#{resource_name}_password_path")
  end

  def new_registration_path(resource_name)
    send(:"new_#{resource_name}_registration_path")
  end
end