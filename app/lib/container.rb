# frozen_string_literal: true

require 'dry-container'
require 'dry-auto_inject'

# 의존성 주입 컨테이너
class Container
  extend Dry::Container::Mixin

  # Repositories
  namespace 'repositories' do
    register 'task' do
      TaskRepository.new
    end

    register 'sprint' do
      SprintRepository.new
    end

    register 'user' do
      UserRepository.new
    end

    register 'organization' do
      OrganizationRepository.new
    end
  end

  # Services
  namespace 'services' do
    register 'task' do
      TaskService.new
    end

    register 'sprint' do
      SprintService.new
    end

    register 'dashboard' do
      DashboardService.new
    end
  end

  # Validators
  namespace 'validators' do
    register 'task_create' do
      Contracts::TaskCreateContract.new
    end

    register 'task_update' do
      Contracts::TaskUpdateContract.new
    end

    register 'sprint_create' do
      Contracts::SprintCreateContract.new
    end
  end

  # Factories
  namespace 'factories' do
    register 'task_dto' do
      ->(model) { Dto::EnhancedTaskDto.from_model(model) }
    end

    register 'sprint_dto' do
      ->(model) { Dto::SprintDto.from_model(model) }
    end
  end
end

# 의존성 주입 헬퍼
Inject = Dry::AutoInject(Container)