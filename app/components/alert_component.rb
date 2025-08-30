# frozen_string_literal: true

class AlertComponent < ViewComponent::Base
  VARIANTS = {
    default: 'bg-primary-50 text-primary-700 border-primary-200',
    info: 'bg-primary-50 text-primary-700 border-primary-200',
    success: 'bg-success-50 text-success-700 border-success-200',
    warning: 'bg-warning-50 text-warning-700 border-warning-200',
    error: 'bg-danger-50 text-danger-700 border-danger-200',
    danger: 'bg-danger-50 text-danger-700 border-danger-200'
  }.freeze

  def initialize(
    type: :info,
    title: nil,
    dismissable: false,
    icon: true,
    **html_options
  )
    @type = type
    @title = title
    @dismissable = dismissable
    @show_icon = icon
    @html_options = html_options
  end

  private

  attr_reader :type, :title, :dismissable, :show_icon, :html_options

  def container_classes
    [
      base_classes,
      variant_classes,
      html_options[:class]
    ].compact.join(' ')
  end

  def base_classes
    'relative rounded-lg border p-4 transition-all duration-200'
  end

  def variant_classes
    VARIANTS[type] || VARIANTS[:default]
  end

  def icon_classes
    'flex-shrink-0 w-5 h-5'
  end

  def title_classes
    'font-medium'
  end

  def content_classes
    'mt-2'
  end

  def dismiss_button_classes
    'absolute top-2 right-2 p-1 rounded-md hover:bg-black/10 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-current transition-colors'
  end

  def show_icon?
    show_icon && icon_path.present?
  end

  def icon_path
    case type
    when :success
      'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z'
    when :warning
      'M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16c-.77.833.192 2.5 1.732 2.5z'
    when :error, :danger
      'M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z'
    else # info, default
      'M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z'
    end
  end
end