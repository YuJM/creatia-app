# frozen_string_literal: true

module Web
  class PermissionAuditLogsController < TenantBaseController
    before_action :set_organization
    before_action :authorize_audit_log_access!

    def index
      # Start with a basic implementation to debug
      @audit_logs = @organization.permission_audit_logs
                                .includes(:user, :resource)
                                .order(created_at: :desc)
                                .limit(50) # Use limit instead of page for now
      
      # Filtering
      if params[:user_id].present?
        @audit_logs = @audit_logs.where(user_id: params[:user_id])
      end
      
      if params[:action].present?
        @audit_logs = @audit_logs.where(action: params[:action])
      end
      
      if params[:permitted].present?
        @audit_logs = @audit_logs.where(permitted: params[:permitted] == 'true')
      end
      
      if params[:resource_type].present?
        @audit_logs = @audit_logs.where(resource_type: params[:resource_type])
      end
      
      if params[:date_from].present?
        @audit_logs = @audit_logs.where('created_at >= ?', params[:date_from])
      end
      
      if params[:date_to].present?
        @audit_logs = @audit_logs.where('created_at <= ?', params[:date_to])
      end
      
      # Statistics for dashboard - simplified
      @stats = {
        total_checks: @organization.permission_audit_logs.count,
        permitted_count: @organization.permission_audit_logs.where(permitted: true).count,
        denied_count: @organization.permission_audit_logs.where(permitted: false).count,
        unique_users: @organization.permission_audit_logs.distinct.count(:user_id),
        today_count: @organization.permission_audit_logs.where(created_at: Date.current.beginning_of_day..).count
      }
      
      # Top denied actions - simplified
      @top_denied = []
      
      respond_to do |format|
        format.html
        format.csv { send_data generate_csv(@audit_logs), filename: "audit_logs_#{Date.current}.csv" }
      end
    end

    def show
      @audit_log = @organization.permission_audit_logs.find(params[:id])
      
      respond_to do |format|
        format.html
      end
    end

    def export
      @audit_logs = @organization.permission_audit_logs
                                .includes(:user, :resource)
                                .where(created_at: params[:start_date]..params[:end_date])
      
      respond_to do |format|
        format.csv { send_data generate_csv(@audit_logs), filename: "audit_logs_export.csv" }
        format.xlsx { render xlsx: 'export', filename: "audit_logs_export.xlsx" }
      end
    end

    private

    def set_organization
      @organization = current_organization
    end

    def authorize_audit_log_access!
      authorize! :read, PermissionAuditLog
    end

    def generate_csv(logs)
      CSV.generate(headers: true) do |csv|
        csv << ['Date', 'Time', 'User', 'Action', 'Resource Type', 'Resource', 'Permitted', 'Details']
        
        logs.each do |log|
          csv << [
            log.created_at.to_date,
            log.created_at.strftime('%H:%M:%S'),
            log.user&.email,
            log.action,
            log.resource_type,
            log.resource&.to_s,
            log.permitted? ? 'Yes' : 'No',
            log.context.to_json
          ]
        end
      end
    end
  end
end