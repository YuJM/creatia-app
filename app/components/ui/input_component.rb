# frozen_string_literal: true

class Ui::InputComponent < ViewComponent::Base
  SIZES = {
    sm: 'h-8 px-3 text-sm',
    default: 'h-10 px-3 text-sm',
    lg: 'h-12 px-4 text-base'
  }.freeze

  def initialize(
    type: 'text',
    size: :default,
    label: nil,
    placeholder: nil,
    value: nil,
    name: nil,
    id: nil,
    required: false,
    disabled: false,
    readonly: false,
    error: nil,
    help_text: nil,
    prefix: nil,
    suffix: nil,
    **html_options
  )
    @type = type
    @size = size
    @label = label
    @placeholder = placeholder
    @value = value
    @name = name
    @id = id || generate_id
    @required = required
    @disabled = disabled
    @readonly = readonly
    @error = error
    @help_text = help_text
    @prefix = prefix
    @suffix = suffix
    @html_options = html_options
  end

  private

  attr_reader :type, :size, :label, :placeholder, :value, :name, :id, :required, :disabled, :readonly, :error, :help_text, :prefix, :suffix, :html_options

  def wrapper_classes
    'flex flex-col gap-2'
  end

  def input_wrapper_classes
    classes = ['relative flex items-center']
    classes << 'opacity-50' if disabled
    classes.join(' ')
  end

  def input_classes
    [
      base_classes,
      size_classes,
      state_classes,
      prefix_suffix_classes,
      html_options[:class]
    ].compact.join(' ')
  end

  def base_classes
    'input flex w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50'
  end

  def size_classes
    SIZES[size] || SIZES[:default]
  end

  def state_classes
    if error.present?
      'border-danger-500 text-danger-600 focus-visible:ring-danger-500'
    else
      ''
    end
  end

  def prefix_suffix_classes
    classes = []
    classes << 'pl-10' if prefix.present?
    classes << 'pr-10' if suffix.present?
    classes.join(' ')
  end

  def input_attributes
    attrs = html_options.except(:class)
    attrs.merge!({
      type: type,
      class: input_classes,
      id: id,
      name: name,
      placeholder: placeholder,
      value: value,
      required: required,
      disabled: disabled,
      readonly: readonly
    })
    attrs.compact
  end

  def label_classes
    base = 'text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70'
    error.present? ? "#{base} text-danger-600" : base
  end

  def help_text_classes
    base = 'text-sm'
    error.present? ? "#{base} text-danger-600" : "#{base} text-muted-foreground"
  end

  def prefix_suffix_classes_for_element
    'absolute inset-y-0 flex items-center px-3 text-muted-foreground'
  end

  def generate_id
    "input_#{SecureRandom.hex(4)}"
  end

  def show_label?
    label.present?
  end

  def show_help_text?
    help_text.present? || error.present?
  end

  def display_help_text
    error.present? ? error : help_text
  end

  def icon_path(icon)
    case icon
    when :email, :mail
      'M16 12a4 4 0 10-8 0 4 4 0 008 0zM16 12v1.5a2.5 2.5 0 005 0V12a9 9 0 10-9 9m4.5-1.206a8.959 8.959 0 01-4.5 1.207'
    when :user
      'M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z'
    when :search
      'M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z'
    when :phone
      'M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z'
    when :calendar
      'M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z'
    when :lock
      'M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z'
    else
      'M12 4v16m8-8H4'
    end
  end
end