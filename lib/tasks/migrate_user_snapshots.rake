# frozen_string_literal: true

namespace :migration do
  desc "기존 embedded UserSnapshot 데이터를 별도 컬렉션으로 마이그레이션"
  task migrate_user_snapshots: :environment do
    puts "=== UserSnapshot 마이그레이션 시작 ==="
    
    # 1. 기존 Task에서 embedded 스냅샷 데이터 수집
    puts "1. 기존 Task embedded 스냅샷 데이터 수집 중..."
    
    migrated_count = 0
    error_count = 0
    
    Task.all.each do |task|
      begin
        # Assignee 스냅샷 마이그레이션
        if task.assignee_id.present?
          migrate_assignee_snapshot(task)
          migrated_count += 1
        end
        
        # Reviewer 스냅샷 마이그레이션
        if task.reviewer_id.present?
          migrate_reviewer_snapshot(task)
          migrated_count += 1
        end
        
      rescue => e
        error_count += 1
        puts "ERROR: Task #{task.id} 마이그레이션 실패: #{e.message}"
      end
      
      print "." if (migrated_count + error_count) % 10 == 0
    end
    
    puts "\n2. Sprint 스냅샷 마이그레이션 중..."
    
    Sprint.all.each do |sprint|
      begin
        # Created by 스냅샷 마이그레이션
        if sprint.created_by_id.present?
          migrate_sprint_creator_snapshot(sprint)
          migrated_count += 1
        end
        
      rescue => e
        error_count += 1
        puts "ERROR: Sprint #{sprint.id} 마이그레이션 실패: #{e.message}"
      end
      
      print "." if (migrated_count + error_count) % 10 == 0
    end
    
    puts "\n=== 마이그레이션 완료 ==="
    puts "성공: #{migrated_count}개 스냅샷"
    puts "실패: #{error_count}개"
    puts "UserSnapshot 컬렉션 총 개수: #{UserSnapshot.count}"
  end
  
  private
  
  def migrate_assignee_snapshot(task)
    return unless task.assignee_id.present?
    
    # PostgreSQL에서 User 조회
    user = User.find_by(id: task.assignee_id)
    return unless user
    
    # UserSnapshot 생성 또는 업데이트
    snapshot = UserSnapshot.where(user_id: user.id.to_s).first
    
    if snapshot.present?
      snapshot.sync_from_user!(user)
    else
      snapshot = UserSnapshot.from_user(user)
      snapshot.save!
    end
    
    # Task에 스냅샷 ID 설정
    task.assignee_snapshot_id = snapshot.id.to_s
    task.save!
    
    puts "  ✓ Task #{task.id} assignee 스냅샷 마이그레이션 완료"
  end
  
  def migrate_reviewer_snapshot(task)
    return unless task.reviewer_id.present?
    
    user = User.find_by(id: task.reviewer_id)
    return unless user
    
    snapshot = UserSnapshot.where(user_id: user.id.to_s).first
    
    if snapshot.present?
      snapshot.sync_from_user!(user)
    else
      snapshot = UserSnapshot.from_user(user)
      snapshot.save!
    end
    
    task.reviewer_snapshot_id = snapshot.id.to_s
    task.save!
    
    puts "  ✓ Task #{task.id} reviewer 스냅샷 마이그레이션 완료"
  end
  
  def migrate_sprint_creator_snapshot(sprint)
    return unless sprint.created_by_id.present?
    
    user = User.find_by(id: sprint.created_by_id)
    return unless user
    
    snapshot = UserSnapshot.where(user_id: user.id.to_s).first
    
    if snapshot.present?
      snapshot.sync_from_user!(user)
    else
      snapshot = UserSnapshot.from_user(user)
      snapshot.save!
    end
    
    sprint.created_by_snapshot_id = snapshot.id.to_s
    sprint.save!
    
    puts "  ✓ Sprint #{sprint.id} creator 스냅샷 마이그레이션 완료"
  end
end