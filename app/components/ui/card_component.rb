# frozen_string_literal: true

class Ui::CardComponent < ViewComponent::Base
  VARIANTS = {
    default: 'bg-card text-card-foreground shadow-soft',
    elevated: 'bg-card text-card-foreground shadow-medium',
    outlined: 'bg-card text-card-foreground border border-border shadow-none',
    ghost: 'bg-transparent shadow-none'
  }.freeze

  PADDING = {
    none: '',
    sm: 'p-4',
    default: 'p-6',
    lg: 'p-8',
    xl: 'p-10'
  }.freeze

  def initialize(
    variant: :default,
    padding: :default,
    hover: false,
    clickable: false,
    **html_options
  )
    @variant = variant
    @padding = padding
    @hover = hover
    @clickable = clickable
    @html_options = html_options
  end

  private

  attr_reader :variant, :padding, :hover, :clickable, :html_options

  def classes
    [
      base_classes,
      variant_classes,
      padding_classes,
      interaction_classes,
      html_options[:class]
    ].compact.join(' ')
  end

  def base_classes
    'card rounded-lg transition-all duration-200'
  end

  def variant_classes
    VARIANTS[variant] || VARIANTS[:default]
  end

  def padding_classes
    PADDING[padding] || PADDING[:default]
  end

  def interaction_classes
    classes = []
    classes << 'hover:shadow-medium hover:-translate-y-1' if hover
    classes << 'cursor-pointer focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2' if clickable
    classes.join(' ')
  end

  def card_attributes
    attrs = html_options.except(:class)
    attrs[:class] = classes
    attrs[:tabindex] = '0' if clickable
    attrs[:role] = 'button' if clickable
    attrs
  end
end