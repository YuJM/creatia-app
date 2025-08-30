# frozen_string_literal: true

class Ui::ThemeToggleComponent < ViewComponent::Base
  def initialize(
    show_text: false,
    variant: :default,
    size: :default,
    **html_options
  )
    @show_text = show_text
    @variant = variant
    @size = size
    @html_options = html_options
  end

  private

  attr_reader :show_text, :variant, :size, :html_options

  def button_classes
    base = case variant
           when :ghost
             'inline-flex items-center gap-2 p-2 rounded-md hover:bg-muted transition-colors'
           when :outline
             'inline-flex items-center gap-2 px-3 py-2 rounded-md border border-border hover:bg-muted transition-colors'
           else
             'inline-flex items-center gap-2 px-3 py-2 rounded-md bg-secondary text-secondary-foreground hover:bg-secondary/80 transition-colors'
           end
    
    size_class = case size
                 when :sm
                   'text-sm'
                 when :lg
                   'text-lg p-3'
                 else
                   'text-base'
                 end
    
    "#{base} #{size_class} focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
  end

  def wrapper_attributes
    {
      data: {
        controller: 'theme',
        action: 'click->theme#toggle'
      }.merge(html_options[:data] || {}),
      class: html_options[:class]
    }
  end

  def button_attributes
    {
      type: 'button',
      class: button_classes,
      data: {
        theme_target: 'toggle'
      },
      'aria-label': 'Toggle theme'
    }
  end
end