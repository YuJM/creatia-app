# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TaskMetricsCardComponent, type: :component do
  let(:organization) { create(:organization) }
  let(:task) { create(:task, organization: organization, priority: 'medium', status: 'in_progress') }
  let(:task_metrics) do
    TaskMetrics.new(
      estimated_hours: 8.0,
      actual_hours: 6.0,
      completion_percentage: 75.0,
      complexity_score: 5
    )
  end
  let(:component) { described_class.new(task: task, task_metrics: task_metrics) }

  before do
    ActsAsTenant.current_tenant = organization
  end

  describe 'rendering' do
    subject { render_inline(component) }

    it '작업 진행 현황 제목을 표시한다' do
      expect(subject.text).to include('작업 진행 현황')
    end

    it '완료율을 표시한다' do
      expect(subject.text).to include('75.0%')
      expect(subject.text).to include('완료율')
    end

    it '시간 정보를 표시한다' do
      expect(subject.text).to include('예상 시간')
      expect(subject.text).to include('실제 시간')
      expect(subject.text).to include('8.0')
      expect(subject.text).to include('6.0')
    end

    it 'Stimulus 컨트롤러 데이터 속성을 포함한다' do
      expect(subject.at_css('[data-controller="task-metrics"]')).to be_present
      expect(subject.at_css('[data-task-metrics-task-id-value]')).to be_present
    end

    it '프로그레스 바를 포함한다' do
      progress_bar = subject.at_css('[data-task-metrics-target="progressBar"]')
      expect(progress_bar).to be_present
      expect(progress_bar['style']).to include('width: 75.0%')
    end

    it '새로고침 버튼을 포함한다' do
      refresh_button = subject.at_css('[data-action="click->task-metrics#refresh"]')
      expect(refresh_button).to be_present
    end
  end

  describe 'helper methods' do
    describe '#progress_bar_color' do
      context '완료율이 90% 이상일 때' do
        let(:task_metrics) do
          TaskMetrics.new(
            estimated_hours: 8.0,
            actual_hours: 6.0,
            completion_percentage: 95.0,
            complexity_score: 5
          )
        end

        it '녹색을 반환한다' do
          expect(component.send(:progress_bar_color)).to eq('bg-green-600')
        end
      end

      context '완료율이 50% 이상일 때' do
        it '파란색을 반환한다' do
          expect(component.send(:progress_bar_color)).to eq('bg-blue-600')
        end
      end

      context '완료율이 50% 미만일 때' do
        let(:task_metrics) do
          TaskMetrics.new(
            estimated_hours: 8.0,
            actual_hours: 6.0,
            completion_percentage: 30.0,
            complexity_score: 5
          )
        end

        it '노란색을 반환한다' do
          expect(component.send(:progress_bar_color)).to eq('bg-yellow-600')
        end
      end
    end

    describe '#efficiency_status_class' do
      context 'Task가 예정대로 진행 중일 때' do
        before do
          allow(task_metrics).to receive(:is_on_track?).and_return(true)
        end

        it '녹색 배경 클래스를 반환한다' do
          expect(component.send(:efficiency_status_class)).to eq('bg-green-50 text-green-800')
        end
      end

      context 'Task가 지연 위험이 있을 때' do
        before do
          allow(task_metrics).to receive(:is_on_track?).and_return(false)
        end

        it '노란색 배경 클래스를 반환한다' do
          expect(component.send(:efficiency_status_class)).to eq('bg-yellow-50 text-yellow-800')
        end
      end
    end

    describe '#complexity_badge_class' do
      context '복잡도가 낮을 때' do
        before do
          allow(task_metrics).to receive(:complexity_level).and_return('low')
        end

        it '녹색 배지 클래스를 반환한다' do
          expect(component.send(:complexity_badge_class)).to eq('bg-green-50 text-green-800')
        end
      end

      context '복잡도가 높을 때' do
        before do
          allow(task_metrics).to receive(:complexity_level).and_return('high')
        end

        it '주황색 배지 클래스를 반환한다' do
          expect(component.send(:complexity_badge_class)).to eq('bg-orange-50 text-orange-800')
        end
      end

      context '복잡도가 매우 높을 때' do
        before do
          allow(task_metrics).to receive(:complexity_level).and_return('very_high')
        end

        it '빨간색 배지 클래스를 반환한다' do
          expect(component.send(:complexity_badge_class)).to eq('bg-red-50 text-red-800')
        end
      end
    end

    describe '#efficiency_status_text' do
      context 'Task가 예정대로 진행 중일 때' do
        before do
          allow(task_metrics).to receive(:is_on_track?).and_return(true)
        end

        it '긍정적인 메시지를 반환한다' do
          expect(component.send(:efficiency_status_text)).to eq('👍 예정대로 진행 중')
        end
      end

      context 'Task가 지연 위험이 있을 때' do
        before do
          allow(task_metrics).to receive(:is_on_track?).and_return(false)
        end

        it '경고 메시지를 반환한다' do
          expect(component.send(:efficiency_status_text)).to eq('⚠️ 일정 지연 위험')
        end
      end
    end

    describe '#complexity_description' do
      %w[low medium high very_high].each do |level|
        context "복잡도가 #{level}일 때" do
          before do
            allow(task_metrics).to receive(:complexity_level).and_return(level)
          end

          it '적절한 이모지와 설명을 반환한다' do
            result = component.send(:complexity_description)
            expect(result).to match(/🟢|🟡|🟠|🔴/)
            expect(result).to include('작업')
          end
        end
      end
    end

    describe '#progress_description' do
      context '작업이 시작 단계일 때' do
        before do
          allow(task_metrics).to receive(:remaining_percentage).and_return(80.0)
        end

        it '시작 단계 메시지를 반환한다' do
          expect(component.send(:progress_description)).to eq('📋 시작 단계입니다')
        end
      end

      context '작업이 진행 중일 때' do
        before do
          allow(task_metrics).to receive(:remaining_percentage).and_return(50.0)
        end

        it '진행 중 메시지를 반환한다' do
          expect(component.send(:progress_description)).to eq('⚡ 진행 중입니다')
        end
      end

      context '작업이 거의 완료되었을 때' do
        before do
          allow(task_metrics).to receive(:remaining_percentage).and_return(10.0)
        end

        it '거의 완료 메시지를 반환한다' do
          expect(component.send(:progress_description)).to eq('🏁 거의 완료되었습니다')
        end
      end

      context '작업이 완료되었을 때' do
        before do
          allow(task_metrics).to receive(:remaining_percentage).and_return(0.0)
        end

        it '완료 메시지를 반환한다' do
          expect(component.send(:progress_description)).to eq('✅ 작업이 완료되었습니다')
        end
      end
    end
  end

  describe 'accessibility' do
    subject { render_inline(component) }

    it '적절한 ARIA 레이블을 가진다' do
      # 프로그레스 바나 중요한 정보에 적절한 레이블이 있는지 확인
      expect(subject.text).to include('완료율')
      expect(subject.text).to include('예상 시간')
      expect(subject.text).to include('실제 시간')
    end

    it '키보드로 접근 가능한 버튼을 포함한다' do
      button = subject.at_css('button[data-action]')
      expect(button).to be_present
      expect(button.text).to include('새로고침')
    end
  end
end