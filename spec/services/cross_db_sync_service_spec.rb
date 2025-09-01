# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CrossDbSyncService, type: :service do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:enhanced_task) { create(:enhanced_task, organization_id: organization.id, assignee_id: user.id) }
  
  describe '.sync_user_changes' do
    context 'valid user_id가 주어졌을 때' do
      it '동기화 작업을 스케줄한다' do
        expect(SyncUserDataJob).to receive(:perform_later).with(user.id, ['name'])
        
        result = described_class.sync_user_changes(user.id, ['name'])
        
        expect(result).to be_success
        expect(result.value![:user_id]).to eq(user.id)
        expect(result.value![:sync_scheduled]).to be true
      end
    end
    
    context 'invalid user_id가 주어졌을 때' do
      it 'failure를 반환한다' do
        result = described_class.sync_user_changes(nil)
        
        expect(result).to be_failure
        expect(result.failure).to eq(:invalid_user_id)
      end
    end
  end
  
  describe '.sync_health_check' do
    before do
      # Fresh task
      create(:enhanced_task, 
        organization_id: organization.id,
        snapshots_synced_at: 30.minutes.ago
      )
      
      # Stale task
      create(:enhanced_task, 
        organization_id: organization.id,
        snapshots_synced_at: 2.hours.ago
      )
      
      # Never synced task
      create(:enhanced_task, 
        organization_id: organization.id,
        snapshots_synced_at: nil
      )
    end
    
    it '헬스체크 정보를 반환한다' do
      result = described_class.sync_health_check
      
      expect(result).to be_success
      
      health = result.value!
      expect(health[:total_tasks]).to eq(3)
      expect(health[:fresh_tasks]).to eq(1)
      expect(health[:stale_tasks]).to eq(1)
      expect(health[:never_synced]).to eq(1)
      expect(health[:health_score]).to be_a(Float)
      expect(health[:status]).to be_in(['healthy', 'warning', 'critical'])
    end
  end
  
  describe '.batch_sync_stale_data' do
    it '오래된 Task들을 배치 동기화한다' do
      stale_task = create(:enhanced_task, 
        organization_id: organization.id,
        snapshots_synced_at: 2.days.ago
      )
      
      expect(BatchSyncStaleDataJob).to receive(:perform_later)
        .with([stale_task.id.to_s])
      
      result = described_class.batch_sync_stale_data
      
      expect(result).to be_success
      expect(result.value![:stale_tasks_count]).to eq(1)
    end
  end
end

RSpec.describe SyncUserDataJob, type: :job do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, name: 'Original Name') }
  let!(:assignee_task) do
    create(:enhanced_task, 
      organization_id: organization.id,
      assignee_id: user.id,
      assignee_snapshot: {}
    )
  end
  let!(:creator_task) do
    create(:enhanced_task, 
      organization_id: organization.id,
      creator_id: user.id,
      creator_snapshot: {}
    )
  end
  
  it 'User 정보를 MongoDB 문서에 동기화한다' do
    expect {
      described_class.new.perform(user.id, ['name'])
    }.to change { assignee_task.reload.assignee_snapshot['name'] }
      .from(nil).to(user.name)
      .and change { creator_task.reload.creator_snapshot['name'] }
      .from(nil).to(user.name)
  end
  
  it '동기화 시간을 업데이트한다' do
    freeze_time do
      described_class.new.perform(user.id, ['name'])
      
      expect(assignee_task.reload.snapshots_synced_at).to be_within(1.second).of(Time.current)
      expect(creator_task.reload.snapshots_synced_at).to be_within(1.second).of(Time.current)
    end
  end
  
  it '존재하지 않는 사용자는 무시한다' do
    expect {
      described_class.new.perform('nonexistent-id')
    }.not_to raise_error
  end
end

RSpec.describe UpdateTaskSnapshotJob, type: :job do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, name: 'Test User') }
  let(:task) do
    create(:enhanced_task,
      organization_id: organization.id,
      assignee_id: user.id,
      assignee_snapshot: {}
    )
  end
  
  it 'assignee 스냅샷을 업데이트한다' do
    expect {
      described_class.new.perform(task.id.to_s, 'assignee')
    }.to change { task.reload.assignee_snapshot['name'] }
      .from(nil).to(user.name)
  end
  
  it 'sync_version을 증가시킨다' do
    expect {
      described_class.new.perform(task.id.to_s, 'assignee')
    }.to change { task.reload.sync_version }.by(1)
  end
  
  it '모든 스냅샷을 한번에 업데이트할 수 있다' do
    org = create(:organization, name: 'Test Org')
    task.update!(organization_id: org.id)
    
    expect(task).to receive(:sync_user_snapshots!)
    
    described_class.new.perform(task.id.to_s, 'all')
  end
end