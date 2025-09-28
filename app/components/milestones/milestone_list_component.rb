# frozen_string_literal: true

module Milestones
  class MilestoneListComponent < ViewComponent::Base
    include Turbo::FramesHelper

    def initialize(milestones:, organization:, current_user:)
      @milestones = milestones
      @organization = organization
      @current_user = current_user
    end

    private

    attr_reader :milestones, :organization, :current_user

    def status_badge_class(status)
      base_class = "px-2 py-1 rounded-full text-xs font-medium"
      
      case status
      when 'planning'
        "#{base_class} bg-gray-100 text-gray-700"
      when 'active'
        "#{base_class} bg-blue-100 text-blue-700"
      when 'completed'
        "#{base_class} bg-green-100 text-green-700"
      when 'cancelled'
        "#{base_class} bg-red-100 text-red-700"
      else
        "#{base_class} bg-gray-100 text-gray-700"
      end
    end

    def health_status_icon(health_status)
      case health_status
      when 'on_track'
        tag.span("✅", class: "text-green-600")
      when 'at_risk'
        tag.span("⚠️", class: "text-yellow-600")
      when 'critical'
        tag.span("🚨", class: "text-red-600")
      else
        tag.span("", class: "text-gray-400")
      end
    end

    def progress_color_class(percentage)
      case percentage
      when 0...30
        "bg-red-500"
      when 30...70
        "bg-yellow-500"
      when 70...100
        "bg-green-500"
      else
        "bg-blue-500"
      end
    end

    def format_date(date)
      return "Not set" unless date
      date.strftime("%b %d, %Y")
    end

    def days_remaining_text(milestone)
      return "N/A" unless milestone.planned_end
      
      days = milestone.days_remaining
      
      if days < 0
        tag.span("#{days.abs} days overdue", class: "text-red-600 font-medium")
      elsif days == 0
        tag.span("Due today", class: "text-yellow-600 font-medium")
      elsif days <= 7
        tag.span("#{days} days left", class: "text-yellow-600")
      else
        tag.span("#{days} days left", class: "text-gray-600")
      end
    end

    def milestone_type_icon(type)
      case type
      when 'release'
        "🚀"
      when 'feature'
        "✨"
      when 'business'
        "💼"
      else
        "📌"
      end
    end
  end
end