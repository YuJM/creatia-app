# frozen_string_literal: true

class Ui::ModalComponent < ViewComponent::Base
  SIZES = {
    sm: 'max-w-md',
    default: 'max-w-lg',
    lg: 'max-w-xl',
    xl: 'max-w-2xl',
    xxl: 'max-w-4xl',
    full: 'max-w-full mx-4'
  }.freeze

  def initialize(
    id: nil,
    title: nil,
    size: :default,
    closable: true,
    backdrop_close: true,
    **html_options
  )
    @id = id || generate_id
    @title = title
    @size = size
    @closable = closable
    @backdrop_close = backdrop_close
    @html_options = html_options
  end

  private

  attr_reader :id, :title, :size, :closable, :backdrop_close, :html_options

  def modal_attributes
    {
      id: id,
      class: modal_classes,
      data: {
        controller: 'modal',
        modal_closable_value: closable,
        modal_backdrop_close_value: backdrop_close
      }.merge(html_options[:data] || {}),
      role: 'dialog',
      'aria-modal': 'true',
      'aria-labelledby': title_id,
      tabindex: '-1'
    }
  end

  def modal_classes
    [
      'fixed inset-0 z-50 hidden',
      'bg-black/50 backdrop-blur-sm',
      'flex items-center justify-center p-4',
      'animate-fade-in',
      html_options[:class]
    ].compact.join(' ')
  end

  def content_classes
    [
      'relative w-full rounded-lg',
      'bg-card text-card-foreground',
      'shadow-hard border border-border',
      'animate-scale-in',
      size_classes
    ].join(' ')
  end

  def size_classes
    SIZES[size] || SIZES[:default]
  end

  def header_classes
    'flex items-center justify-between p-6 pb-4 border-b border-border'
  end

  def body_classes
    'p-6'
  end

  def footer_classes
    'flex items-center justify-end gap-3 p-6 pt-4 border-t border-border'
  end

  def title_classes
    'text-lg font-semibold leading-none tracking-tight'
  end

  def close_button_classes
    'absolute right-4 top-4 rounded-sm opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:pointer-events-none'
  end

  def title_id
    "#{id}-title"
  end

  def generate_id
    "modal_#{SecureRandom.hex(4)}"
  end

  def render_header?
    title.present? || closable
  end

  def render_footer?
    content_for?(:modal_footer)
  end
end