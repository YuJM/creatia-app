# frozen_string_literal: true

class DashboardCustomizationController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user_dashboard
  before_action :set_available_widgets, only: [:show, :update]

  def show
    @user_preferences = @user_dashboard.preferences || default_preferences
    @available_layouts = available_dashboard_layouts
    @widget_configurations = @user_dashboard.widget_configurations || {}

    respond_to do |format|
      format.html
      format.json { render_serialized(DashboardCustomizationSerializer, customization_json_response) }
      format.turbo_stream
    end
  end

  def update
    begin
      ActiveRecord::Base.transaction do
        update_dashboard_layout
        update_widget_configurations
        update_user_preferences
        update_theme_settings
        
        @user_dashboard.save!
        clear_dashboard_cache
      end

      respond_to do |format|
        format.html { redirect_to dashboard_customization_path, notice: '대시보드 설정이 저장되었습니다.' }
        format.json { render_serialized(DashboardCustomizationSerializer, { success: true, message: '설정이 저장되었습니다.' }) }
        format.turbo_stream { render :update_success }
      end
    rescue => error
      Rails.logger.error "Dashboard customization error: #{error.message}"
      
      respond_to do |format|
        format.html { render :show, status: :unprocessable_entity, alert: '설정 저장에 실패했습니다.' }
        format.json { render_serialized(DashboardCustomizationSerializer, { success: false, error: error.message }, status: :unprocessable_entity) }
        format.turbo_stream { render :update_error }
      end
    end
  end

  def reset
    @user_dashboard.update!(
      layout: 'default',
      preferences: default_preferences,
      widget_configurations: default_widget_configurations,
      theme_settings: default_theme_settings
    )
    
    clear_dashboard_cache
    
    respond_to do |format|
      format.html { redirect_to dashboard_customization_path, notice: '대시보드가 기본 설정으로 초기화되었습니다.' }
      format.json { render_serialized(DashboardCustomizationSerializer, { success: true, message: '기본 설정으로 초기화되었습니다.' }) }
      format.turbo_stream { render :reset_success }
    end
  end

  def preview
    preview_layout = params[:layout] || 'default'
    preview_widgets = parse_widget_params(params[:widgets])
    preview_theme = params[:theme] || 'light'

    @preview_data = generate_preview_data(preview_layout, preview_widgets, preview_theme)

    respond_to do |format|
      format.html { render :preview }
      format.json { render_serialized(DashboardCustomizationSerializer, { success: true, preview: @preview_data }) }
      format.turbo_stream { render :preview_update }
    end
  end

  def widgets
    case request.method
    when 'POST'
      add_widget
    when 'DELETE'
      remove_widget
    when 'PATCH', 'PUT'
      update_widget_position
    else
      list_widgets
    end
  end

  private

  def set_user_dashboard
    @user_dashboard = current_user.dashboard_customization || 
                     current_user.create_dashboard_customization(
                       layout: 'default',
                       preferences: default_preferences,
                       widget_configurations: default_widget_configurations
                     )
  end

  def set_available_widgets
    @available_widgets = {
      metrics: {
        id: 'metrics',
        name: '팀 메트릭',
        description: '팀의 속도, 완료율, 처리 시간 등 핵심 지표',
        category: 'analytics',
        size: 'large',
        configurable: true,
        default_config: {
          show_velocity: true,
          show_completion_rate: true,
          show_cycle_time: true,
          auto_refresh: true,
          refresh_interval: 30000
        }
      },
      tasks_summary: {
        id: 'tasks_summary',
        name: '내 작업 요약',
        description: '담당자로 배정된 작업들의 현황과 우선순위',
        category: 'tasks',
        size: 'medium',
        configurable: true,
        default_config: {
          show_overdue: true,
          show_due_today: true,
          show_priority: true,
          max_items: 10
        }
      },
      recent_activity: {
        id: 'recent_activity',
        name: '최근 활동',
        description: '프로젝트의 최근 변경사항과 업데이트',
        category: 'activity',
        size: 'medium',
        configurable: true,
        default_config: {
          show_comments: true,
          show_status_changes: true,
          show_assignments: true,
          max_items: 15
        }
      },
      sprint_progress: {
        id: 'sprint_progress',
        name: '스프린트 진행률',
        description: '현재 스프린트의 번다운 차트와 목표 달성률',
        category: 'sprints',
        size: 'large',
        configurable: true,
        default_config: {
          show_burndown: true,
          show_velocity: true,
          show_remaining_work: true
        }
      },
      calendar: {
        id: 'calendar',
        name: '캘린더',
        description: '마일스톤, 스프린트 일정, 개인 일정',
        category: 'planning',
        size: 'large',
        configurable: true,
        default_config: {
          show_milestones: true,
          show_sprints: true,
          show_personal: true,
          view_mode: 'month'
        }
      },
      team_workload: {
        id: 'team_workload',
        name: '팀 업무량',
        description: '팀원별 업무 분배 현황과 용량 활용도',
        category: 'team',
        size: 'medium',
        configurable: true,
        default_config: {
          show_capacity: true,
          show_allocation: true,
          alert_overload: true
        }
      },
      notifications: {
        id: 'notifications',
        name: '알림',
        description: '중요한 업데이트와 알림 메시지',
        category: 'communication',
        size: 'small',
        configurable: false,
        default_config: {
          max_items: 5
        }
      },
      quick_actions: {
        id: 'quick_actions',
        name: '빠른 작업',
        description: '자주 사용하는 기능들의 바로가기',
        category: 'productivity',
        size: 'small',
        configurable: true,
        default_config: {
          show_create_task: true,
          show_create_sprint: true,
          show_reports: true
        }
      }
    }
  end

  def available_dashboard_layouts
    {
      default: {
        name: '기본 레이아웃',
        description: '2열 레이아웃으로 메인 콘텐츠와 사이드바 구성',
        columns: 2,
        grid_template: 'auto 1fr',
        areas: [
          ['main', 'sidebar'],
          ['main', 'sidebar']
        ]
      },
      three_column: {
        name: '3열 레이아웃',
        description: '3열 레이아웃으로 더 많은 위젯 공간 제공',
        columns: 3,
        grid_template: '1fr 1fr 1fr',
        areas: [
          ['left', 'center', 'right']
        ]
      },
      focus: {
        name: '집중 레이아웃',
        description: '단일 열 레이아웃으로 집중력 향상',
        columns: 1,
        grid_template: '1fr',
        areas: [
          ['main']
        ]
      },
      dashboard: {
        name: '대시보드 레이아웃',
        description: '다양한 크기의 위젯을 효율적으로 배치',
        columns: 4,
        grid_template: '1fr 1fr 1fr 1fr',
        areas: [
          ['large', 'large', 'medium', 'small'],
          ['large', 'large', 'medium', 'small'],
          ['wide', 'wide', 'wide', 'narrow']
        ]
      }
    }
  end

  def default_preferences
    {
      theme: 'light',
      density: 'comfortable',
      animations: true,
      auto_refresh: true,
      refresh_interval: 60000,
      notifications: {
        email: true,
        browser: true,
        sound: false
      },
      language: 'ko'
    }
  end

  def default_widget_configurations
    {
      'metrics' => { position: { row: 0, col: 0, width: 2, height: 1 }, enabled: true },
      'tasks_summary' => { position: { row: 0, col: 2, width: 1, height: 1 }, enabled: true },
      'recent_activity' => { position: { row: 1, col: 0, width: 1, height: 2 }, enabled: true },
      'sprint_progress' => { position: { row: 1, col: 1, width: 2, height: 1 }, enabled: true },
      'notifications' => { position: { row: 0, col: 3, width: 1, height: 1 }, enabled: true }
    }
  end

  def default_theme_settings
    {
      primary_color: '#3b82f6',
      secondary_color: '#64748b',
      accent_color: '#10b981',
      background_color: '#ffffff',
      surface_color: '#f8fafc',
      text_color: '#1e293b',
      border_radius: 'md',
      shadows: true
    }
  end

  def customization_json_response
    {
      success: true,
      dashboard: {
        id: @user_dashboard.id,
        layout: @user_dashboard.layout,
        preferences: @user_preferences,
        widgets: @widget_configurations,
        theme: @user_dashboard.theme_settings || default_theme_settings
      },
      available: {
        widgets: @available_widgets,
        layouts: @available_layouts,
        themes: available_themes
      }
    }
  end

  def available_themes
    {
      light: {
        name: '라이트 테마',
        primary_color: '#3b82f6',
        background_color: '#ffffff',
        surface_color: '#f8fafc'
      },
      dark: {
        name: '다크 테마',
        primary_color: '#60a5fa',
        background_color: '#0f172a',
        surface_color: '#1e293b'
      },
      blue: {
        name: '블루 테마',
        primary_color: '#1e40af',
        background_color: '#f0f9ff',
        surface_color: '#e0f2fe'
      },
      green: {
        name: '그린 테마',
        primary_color: '#059669',
        background_color: '#f0fdf4',
        surface_color: '#dcfce7'
      }
    }
  end

  def update_dashboard_layout
    if params[:layout].present?
      @user_dashboard.layout = params[:layout]
    end
  end

  def update_widget_configurations
    if params[:widgets].present?
      widgets_params = parse_widget_params(params[:widgets])
      @user_dashboard.widget_configurations = widgets_params
    end
  end

  def update_user_preferences
    if params[:preferences].present?
      current_prefs = @user_dashboard.preferences || default_preferences
      new_prefs = current_prefs.deep_merge(params[:preferences].to_unsafe_h)
      @user_dashboard.preferences = new_prefs
    end
  end

  def update_theme_settings
    if params[:theme_settings].present?
      current_theme = @user_dashboard.theme_settings || default_theme_settings
      new_theme = current_theme.deep_merge(params[:theme_settings].to_unsafe_h)
      @user_dashboard.theme_settings = new_theme
    end
  end

  def parse_widget_params(widgets_param)
    return {} unless widgets_param.is_a?(Hash) || widgets_param.is_a?(ActionController::Parameters)
    
    parsed_widgets = {}
    widgets_param.each do |widget_id, config|
      if config.is_a?(Hash) || config.is_a?(ActionController::Parameters)
        parsed_widgets[widget_id.to_s] = {
          position: config[:position] || {},
          enabled: config[:enabled] != false,
          settings: config[:settings] || {}
        }
      end
    end
    
    parsed_widgets
  end

  def generate_preview_data(layout, widgets, theme)
    {
      layout: layout,
      theme: theme,
      widgets: widgets.map do |widget_id, config|
        widget_data = @available_widgets[widget_id.to_sym]
        next unless widget_data
        
        {
          id: widget_id,
          name: widget_data[:name],
          position: config[:position],
          preview_content: generate_widget_preview(widget_id)
        }
      end.compact
    }
  end

  def generate_widget_preview(widget_id)
    case widget_id
    when 'metrics'
      {
        velocity: 12.5,
        completion_rate: 87.3,
        cycle_time: 3.2
      }
    when 'tasks_summary'
      {
        total: 15,
        overdue: 2,
        due_today: 3,
        in_progress: 6
      }
    when 'recent_activity'
      [
        { type: 'task_completed', message: 'UI 컴포넌트 개발 완료', time: '10분 전' },
        { type: 'comment', message: '새 댓글이 추가됨', time: '1시간 전' },
        { type: 'assignment', message: '새 작업이 배정됨', time: '2시간 전' }
      ]
    else
      { message: '위젯 미리보기 데이터' }
    end
  end

  def add_widget
    widget_id = params[:widget_id]
    widget_config = params[:config] || {}
    
    unless @available_widgets.key?(widget_id.to_sym)
      return render_serialized(DashboardCustomizationSerializer, { success: false, error: '존재하지 않는 위젯입니다' }, status: :unprocessable_entity)
    end
    
    current_widgets = @user_dashboard.widget_configurations || {}
    current_widgets[widget_id] = {
      position: widget_config[:position] || find_available_position,
      enabled: true,
      settings: widget_config[:settings] || @available_widgets[widget_id.to_sym][:default_config]
    }
    
    @user_dashboard.update!(widget_configurations: current_widgets)
    clear_dashboard_cache
    
    render_serialized(DashboardCustomizationSerializer, { success: true, widget: current_widgets[widget_id] })
  end

  def remove_widget
    widget_id = params[:widget_id]
    current_widgets = @user_dashboard.widget_configurations || {}
    
    if current_widgets.key?(widget_id)
      current_widgets.delete(widget_id)
      @user_dashboard.update!(widget_configurations: current_widgets)
      clear_dashboard_cache
      
      render_serialized(DashboardCustomizationSerializer, { success: true, message: '위젯이 제거되었습니다' })
    else
      render_serialized(DashboardCustomizationSerializer, { success: false, error: '위젯을 찾을 수 없습니다' }, status: :not_found)
    end
  end

  def update_widget_position
    widget_id = params[:widget_id]
    new_position = params[:position]
    
    current_widgets = @user_dashboard.widget_configurations || {}
    
    if current_widgets.key?(widget_id)
      current_widgets[widget_id][:position] = new_position
      @user_dashboard.update!(widget_configurations: current_widgets)
      clear_dashboard_cache
      
      render_serialized(DashboardCustomizationSerializer, { success: true, position: new_position })
    else
      render_serialized(DashboardCustomizationSerializer, { success: false, error: '위젯을 찾을 수 없습니다' }, status: :not_found)
    end
  end

  def list_widgets
    render_serialized(DashboardCustomizationSerializer, {
      success: true,
      widget_configurations: @user_dashboard.widget_configurations || {},
      available_widgets: @available_widgets
    })
  end

  def find_available_position
    # 빈 위치를 찾아서 반환하는 로직
    current_widgets = @user_dashboard.widget_configurations || {}
    occupied_positions = current_widgets.values.map { |config| config[:position] }
    
    # 간단한 구현: 다음 빈 자리 찾기
    (0..10).each do |row|
      (0..3).each do |col|
        position = { row: row, col: col, width: 1, height: 1 }
        unless occupied_positions.any? { |pos| positions_overlap?(position, pos) }
          return position
        end
      end
    end
    
    # 기본 위치
    { row: 0, col: 0, width: 1, height: 1 }
  end

  def positions_overlap?(pos1, pos2)
    return false unless pos1 && pos2
    
    pos1_right = pos1[:col] + pos1[:width]
    pos1_bottom = pos1[:row] + pos1[:height]
    pos2_right = pos2[:col] + pos2[:width]
    pos2_bottom = pos2[:row] + pos2[:height]
    
    !(pos1[:col] >= pos2_right || pos2[:col] >= pos1_right || 
      pos1[:row] >= pos2_bottom || pos2[:row] >= pos1_bottom)
  end

  def clear_dashboard_cache
    Rails.cache.delete("user_dashboard_#{current_user.id}")
    Rails.cache.delete("dashboard_widgets_#{current_user.id}")
  end
end