# frozen_string_literal: true

class MilestoneProgressComponent < ViewComponent::Base
  attr_reader :milestone
  
  def initialize(milestone:)
    @milestone = milestone
  end
  
  def render?
    milestone.present?
  end
  
  def call
    tag.div(class: "milestone-progress", data: stimulus_data) do
      safe_join([
        status_badge,
        progress_bar,
        deadline_info,
        risk_indicator
      ])
    end
  end
  
  private
  
  def status_badge
    tag.span(milestone.status.humanize, class: status_classes)
  end
  
  def status_classes
    class_names(
      "px-2 py-1 text-sm font-medium rounded",
      {
        "bg-gray-100 text-gray-800" => milestone.planning?,
        "bg-blue-100 text-blue-800" => milestone.in_progress?,
        "bg-green-100 text-green-800" => milestone.completed?,
        "bg-yellow-100 text-yellow-800" => milestone.delayed?,
        "bg-red-100 text-red-800" => milestone.cancelled?
      }
    )
  end
  
  def progress_bar
    tag.div(class: "mt-2") do
      safe_join([
        tag.div(class: "flex justify-between mb-1") do
          safe_join([
            tag.span("Progress", class: "text-sm font-medium text-gray-700"),
            tag.span("#{milestone.progress}%", class: "text-sm font-medium text-gray-700")
          ])
        end,
        tag.div(class: "w-full bg-gray-200 rounded-full h-2.5") do
          tag.div(class: progress_bar_classes, style: "width: #{milestone.progress}%")
        end
      ])
    end
  end
  
  def progress_bar_classes
    if milestone.is_at_risk?
      "bg-red-600 h-2.5 rounded-full"
    elsif milestone.progress >= 70
      "bg-green-600 h-2.5 rounded-full"
    else
      "bg-blue-600 h-2.5 rounded-full"
    end
  end
  
  def deadline_info
    tag.div(class: "mt-2 text-sm text-gray-600") do
      if milestone.days_remaining > 0
        "#{milestone.days_remaining} days remaining"
      elsif milestone.days_remaining == 0
        tag.span("Due today", class: "text-orange-600 font-semibold")
      else
        tag.span("#{milestone.days_remaining.abs} days overdue", class: "text-red-600 font-semibold")
      end
    end
  end
  
  def risk_indicator
    return unless milestone.is_at_risk?
    
    tag.div(class: "mt-2 p-2 bg-red-50 border border-red-200 rounded") do
      safe_join([
        tag.span("⚠️", class: "mr-1"),
        tag.span("At Risk: ", class: "font-semibold text-red-800"),
        tag.span("Less than 14 days with low progress", class: "text-red-600 text-sm")
      ])
    end
  end
  
  def stimulus_data
    {
      controller: "milestone-progress",
      milestone_progress_id_value: milestone.id,
      milestone_progress_url_value: Rails.application.routes.url_helpers.milestone_path(milestone)
    }
  end
end