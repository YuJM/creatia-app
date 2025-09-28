# frozen_string_literal: true

class Ui::ButtonComponent < ViewComponent::Base
  VARIANTS = {
    default: 'bg-primary hover:bg-primary-600 text-white shadow-sm',
    secondary: 'bg-secondary hover:bg-secondary-600 text-white shadow-sm',
    accent: 'bg-accent hover:bg-accent-600 text-white shadow-sm',
    success: 'bg-success hover:bg-success-600 text-white shadow-sm',
    warning: 'bg-warning hover:bg-warning-600 text-white shadow-sm',
    danger: 'bg-danger hover:bg-danger-600 text-white shadow-sm',
    outline: 'border border-primary-500 text-primary-600 hover:bg-primary-50 dark:hover:bg-primary-950',
    ghost: 'hover:bg-muted text-foreground',
    link: 'text-primary-600 hover:text-primary-700 underline-offset-4 hover:underline p-0'
  }.freeze

  SIZES = {
    sm: 'h-8 px-3 text-sm',
    default: 'h-10 px-4 py-2',
    lg: 'h-12 px-6 text-lg',
    xl: 'h-14 px-8 text-xl',
    icon: 'h-10 w-10 p-0'
  }.freeze

  def initialize(
    variant: :default,
    size: :default,
    disabled: false,
    loading: false,
    icon: nil,
    icon_position: :left,
    full_width: false,
    **html_options
  )
    @variant = variant
    @size = size
    @disabled = disabled
    @loading = loading
    @icon = icon
    @icon_position = icon_position
    @full_width = full_width
    @html_options = html_options
  end

  private

  attr_reader :variant, :size, :disabled, :loading, :icon, :icon_position, :full_width, :html_options

  def classes
    [
      base_classes,
      variant_classes,
      size_classes,
      width_classes,
      state_classes,
      html_options[:class]
    ].compact.join(' ')
  end

  def base_classes
    'btn inline-flex items-center justify-center gap-2 rounded-md font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50'
  end

  def variant_classes
    VARIANTS[variant] || VARIANTS[:default]
  end

  def size_classes
    SIZES[size] || SIZES[:default]
  end

  def width_classes
    full_width ? 'w-full' : nil
  end

  def state_classes
    classes = []
    classes << 'loading' if loading
    classes << 'opacity-50 pointer-events-none' if disabled
    classes.join(' ')
  end

  def button_attributes
    attrs = html_options.except(:class)
    attrs[:class] = classes
    attrs[:disabled] = true if disabled || loading
    attrs[:type] ||= 'button' unless html_options[:href]
    attrs
  end

  def show_icon?
    icon.present? && !loading
  end

  def icon_left?
    icon_position == :left
  end

  def icon_classes
    case size
    when :sm
      'w-4 h-4'
    when :lg
      'w-6 h-6'
    when :xl
      'w-7 h-7'
    when :icon
      'w-5 h-5'
    else
      'w-5 h-5'
    end
  end

  def loading_spinner
    content_tag :svg, 
      class: "animate-spin #{icon_classes}",
      fill: 'none',
      viewBox: '0 0 24 24' do
      concat content_tag(:circle, '', 
        class: 'opacity-25', 
        cx: '12', 
        cy: '12', 
        r: '10', 
        stroke: 'currentColor', 
        'stroke-width': '4')
      concat content_tag(:path, '', 
        class: 'opacity-75', 
        fill: 'currentColor', 
        d: 'M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z')
    end
  end

  def icon_svg
    return unless show_icon?
    
    content_tag :svg, 
      class: icon_classes,
      fill: 'none',
      stroke: 'currentColor',
      viewBox: '0 0 24 24' do
      content_tag(:path, '', 
        'stroke-linecap': 'round', 
        'stroke-linejoin': 'round', 
        'stroke-width': '2', 
        d: icon_path)
    end
  end

  def icon_path
    case icon
    when :plus
      'M12 4v16m8-8H4'
    when :edit
      'M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7'
    when :delete, :trash
      'M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16'
    when :save
      'M7 17L17 7M17 7H7M17 7V17'
    when :settings
      'M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z'
    when :user
      'M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z'
    when :search
      'M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z'
    when :download
      'M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4'
    when :external_link
      'M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6m4-3h6v6m-11 5L18 4'
    when :chevron_down
      'M19 9l-7 7-7-7'
    when :chevron_right
      'M9 18l6-6-6-6'
    when :check
      'M5 13l4 4L19 7'
    when :x, :close
      'M18 6L6 18M6 6l12 12'
    else
      'M12 4v16m8-8H4' # Default to plus icon
    end
  end
end