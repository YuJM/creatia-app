# frozen_string_literal: true

module Timeline
  class TimelineViewComponent < ViewComponent::Base
    include Turbo::FramesHelper
    
    def initialize(organization:, milestones: [], start_date: nil, end_date: nil, view_mode: 'quarter')
      @organization = organization
      @milestones = milestones
      @start_date = start_date || Date.current.beginning_of_quarter
      @end_date = end_date || Date.current.end_of_quarter
      @view_mode = view_mode # 'month', 'quarter', 'year'
    end

    private

    attr_reader :organization, :milestones, :start_date, :end_date, :view_mode

    def timeline_range
      @timeline_range ||= (start_date..end_date)
    end

    def timeline_months
      @timeline_months ||= timeline_range.map(&:beginning_of_month).uniq
    end

    def timeline_weeks
      @timeline_weeks ||= timeline_range.map(&:beginning_of_week).uniq
    end

    def calculate_position(date)
      return 0 unless date
      total_days = (end_date - start_date).to_i
      days_from_start = (date - start_date).to_i
      ((days_from_start.to_f / total_days) * 100).round(2)
    end

    def calculate_width(start_date, end_date)
      return 0 unless start_date && end_date
      total_days = (@end_date - @start_date).to_i
      duration = (end_date - start_date).to_i
      ((duration.to_f / total_days) * 100).round(2)
    end

    def status_color(status)
      case status
      when 'completed' then 'bg-green-500'
      when 'active' then 'bg-blue-500'
      when 'planning' then 'bg-gray-400'
      when 'cancelled' then 'bg-red-500'
      else 'bg-gray-300'
      end
    end

    def health_indicator_color(health_status)
      case health_status
      when 'on_track' then 'text-green-600'
      when 'at_risk' then 'text-yellow-600'
      when 'critical' then 'text-red-600'
      else 'text-gray-600'
      end
    end

    def progress_bar_color(progress)
      case progress
      when 0...30 then 'bg-red-500'
      when 30...70 then 'bg-yellow-500'
      when 70...100 then 'bg-green-500'
      else 'bg-blue-500'
      end
    end

    def format_date(date)
      return '' unless date
      date.strftime('%b %d')
    end

    def format_month(date)
      date.strftime('%B %Y')
    end

    def today_position
      calculate_position(Date.current)
    end

    def is_today_visible?
      timeline_range.include?(Date.current)
    end
  end
end