# app/controllers/web/sprints_controller.rb
module Web
  class SprintsController < BaseController
    before_action :authenticate_user!
    before_action :set_service
    before_action :set_sprint, only: [:show, :edit, :update, :destroy, :burndown, :board]
    
    def index
      @sprints = Mongodb::MongoSprint
        .where(service_id: @service.id)
        .order_by(sprint_number: :desc)
        .page(params[:page])
      
      # 사용자 정보 프리로드
      Mongodb::MongoSprint.preload_users(@sprints)
    end
    
    def show
      @tasks = Mongodb::MongoTask.in_sprint(@sprint.id)
      
      # 태스크 통계
      @stats = {
        total: @tasks.count,
        completed: @tasks.completed.count,
        in_progress: @tasks.in_progress.count,
        todo: @tasks.todo.count,
        story_points: {
          committed: @sprint.committed_points,
          completed: @sprint.completed_points
        }
      }
      
      # 사용자 정보 프리로드
      Mongodb::MongoTask.preload_users(@tasks)
    end
    
    def new
      @sprint = Mongodb::MongoSprint.new(
        service_id: @service.id,
        organization_id: @service.organization_id,
        start_date: Date.current.beginning_of_week,
        end_date: Date.current.end_of_week + 1.week
      )
    end
    
    def create
      @sprint = SprintService.create_sprint(sprint_params.merge(
        service_id: @service.id
      ))
      
      if @sprint.persisted?
        redirect_to web_service_sprint_path(@service, @sprint),
                    notice: 'Sprint가 성공적으로 생성되었습니다.'
      else
        render :new, status: :unprocessable_entity
      end
    end
    
    def edit
    end
    
    def update
      if @sprint.update(sprint_params)
        redirect_to web_service_sprint_path(@service, @sprint),
                    notice: 'Sprint가 성공적으로 업데이트되었습니다.'
      else
        render :edit, status: :unprocessable_entity
      end
    end
    
    def destroy
      @sprint.destroy
      redirect_to web_service_sprints_path(@service),
                  notice: 'Sprint가 삭제되었습니다.'
    end
    
    # Sprint Board (칸반 보드)
    def board
      @tasks_by_status = {
        'backlog' => [],
        'todo' => [],
        'in_progress' => [],
        'review' => [],
        'done' => []
      }
      
      tasks = Mongodb::MongoTask.in_sprint(@sprint.id)
      tasks.each do |task|
        status = task.status
        @tasks_by_status[status] ||= []
        @tasks_by_status[status] << task
      end
      
      # 실시간 업데이트를 위한 채널 구독 정보
      @channel_params = {
        sprint_id: @sprint.id.to_s
      }
    end
    
    # Burndown Chart Data
    def burndown
      @burndown_data = SprintService.get_burndown_data(@sprint.id)
      
      respond_to do |format|
        format.html
        format.json { render json: @burndown_data }
      end
    end
    
    # Sprint 시작
    def start
      @sprint = Mongodb::MongoSprint.find(params[:id])
      
      if SprintService.start_sprint(@sprint.id)
        redirect_to web_service_sprint_path(@service, @sprint),
                    notice: 'Sprint가 시작되었습니다.'
      else
        redirect_to web_service_sprint_path(@service, @sprint),
                    alert: 'Sprint를 시작할 수 없습니다.'
      end
    end
    
    # Sprint 완료
    def complete
      @sprint = Mongodb::MongoSprint.find(params[:id])
      
      if SprintService.complete_sprint(@sprint.id)
        redirect_to web_service_sprint_path(@service, @sprint),
                    notice: 'Sprint가 완료되었습니다.'
      else
        redirect_to web_service_sprint_path(@service, @sprint),
                    alert: 'Sprint를 완료할 수 없습니다.'
      end
    end
    
    private
    
    def set_service
      @service = Service.find(params[:service_id])
    end
    
    def set_sprint
      @sprint = Mongodb::MongoSprint.find(params[:id])
      
      # 권한 체크
      unless @sprint.service_id == @service.id.to_s
        redirect_to web_service_sprints_path(@service),
                    alert: '접근 권한이 없습니다.'
      end
    end
    
    def sprint_params
      params.require(:sprint).permit(
        :name, :goal, :start_date, :end_date,
        :team_id, :milestone_id, :planned_velocity
      )
    end
  end
end