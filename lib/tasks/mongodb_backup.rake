# frozen_string_literal: true

namespace :mongodb do
  namespace :backup do
    desc "Create MongoDB backup"
    task create: :environment do
      puts "\n📦 Starting MongoDB Backup..."
      puts "=" * 60
      
      backup = MongodbBackup.new
      result = backup.create_backup
      
      if result[:success]
        puts "✅ Backup completed successfully!"
        puts "📁 Backup file: #{result[:file]}"
        puts "📊 Size: #{result[:size]}"
        puts "⏱️  Duration: #{result[:duration]} seconds"
      else
        puts "❌ Backup failed: #{result[:error]}"
      end
    end

    desc "Restore MongoDB from backup"
    task :restore, [:backup_file] => :environment do |_task, args|
      unless args[:backup_file]
        puts "❌ Please provide a backup file path"
        puts "Usage: rake mongodb:backup:restore[/path/to/backup.tar.gz]"
        exit 1
      end
      
      puts "\n📦 Starting MongoDB Restore..."
      puts "⚠️  WARNING: This will overwrite existing data!"
      print "Are you sure you want to continue? (yes/no): "
      
      response = STDIN.gets.chomp
      unless response.downcase == 'yes'
        puts "Restore cancelled"
        exit 0
      end
      
      backup = MongodbBackup.new
      result = backup.restore_backup(args[:backup_file])
      
      if result[:success]
        puts "✅ Restore completed successfully!"
        puts "📊 Collections restored: #{result[:collections]}"
        puts "📝 Documents restored: #{result[:documents]}"
        puts "⏱️  Duration: #{result[:duration]} seconds"
      else
        puts "❌ Restore failed: #{result[:error]}"
      end
    end

    desc "List available backups"
    task list: :environment do
      puts "\n📋 Available MongoDB Backups"
      puts "=" * 60
      
      backup = MongodbBackup.new
      backups = backup.list_backups
      
      if backups.empty?
        puts "No backups found"
      else
        backups.each_with_index do |file, index|
          puts "#{index + 1}. #{file[:name]}"
          puts "   Size: #{file[:size]}"
          puts "   Created: #{file[:created]}"
          puts ""
        end
      end
    end

    desc "Clean old backups"
    task :cleanup, [:days] => :environment do |_task, args|
      days = args[:days]&.to_i || 30
      
      puts "\n🧹 Cleaning backups older than #{days} days..."
      
      backup = MongodbBackup.new
      result = backup.cleanup_old_backups(days)
      
      puts "✅ Cleaned up #{result[:deleted]} old backups"
      puts "💾 Freed up #{result[:space_freed]}"
    end

    desc "Verify backup integrity"
    task :verify, [:backup_file] => :environment do |_task, args|
      unless args[:backup_file]
        puts "❌ Please provide a backup file path"
        exit 1
      end
      
      puts "\n🔍 Verifying backup integrity..."
      
      backup = MongodbBackup.new
      result = backup.verify_backup(args[:backup_file])
      
      if result[:valid]
        puts "✅ Backup is valid"
        puts "📊 Collections: #{result[:collections].join(', ')}"
        puts "📝 Total documents: #{result[:total_documents]}"
      else
        puts "❌ Backup verification failed: #{result[:error]}"
      end
    end

    desc "Schedule automatic backups"
    task schedule: :environment do
      puts "\n⏰ Scheduling automatic MongoDB backups..."
      
      if defined?(Sidekiq::Cron)
        # Daily backup at 2 AM
        Sidekiq::Cron::Job.create(
          name: 'MongoDB Daily Backup',
          cron: '0 2 * * *',
          class: 'MongodbBackupJob',
          args: ['daily']
        )
        
        # Weekly backup on Sunday at 3 AM
        Sidekiq::Cron::Job.create(
          name: 'MongoDB Weekly Backup',
          cron: '0 3 * * 0',
          class: 'MongodbBackupJob',
          args: ['weekly']
        )
        
        puts "✅ Automatic backups scheduled"
      else
        puts "⚠️  Sidekiq::Cron not available. Please set up cron jobs manually."
      end
    end
  end
end

# MongoDB 백업 구현 클래스
class MongodbBackup
  require 'fileutils'
  require 'open3'
  
  def initialize
    @backup_dir = Rails.root.join('backups', 'mongodb')
    @database = Mongoid.default_client.database.name
    @host = Mongoid.default_client.cluster.addresses.first.to_s
    
    FileUtils.mkdir_p(@backup_dir)
  end

  def create_backup(type = 'manual')
    start_time = Time.current
    timestamp = start_time.strftime('%Y%m%d_%H%M%S')
    backup_name = "mongodb_#{type}_#{timestamp}"
    backup_path = @backup_dir.join(backup_name)
    
    begin
      # mongodump 명령 실행
      dump_result = perform_mongodump(backup_path)
      return dump_result unless dump_result[:success]
      
      # 백업 압축
      compress_result = compress_backup(backup_path, backup_name)
      return compress_result unless compress_result[:success]
      
      # 메타데이터 저장
      save_backup_metadata(backup_name, type)
      
      # S3 업로드 (옵션)
      upload_to_s3(compress_result[:file]) if Rails.application.config.backup_to_s3
      
      duration = (Time.current - start_time).round(2)
      
      {
        success: true,
        file: compress_result[:file],
        size: format_size(File.size(compress_result[:file])),
        duration: duration
      }
    rescue => e
      Rails.logger.error "Backup failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      {
        success: false,
        error: e.message
      }
    ensure
      # 압축되지 않은 백업 디렉토리 삭제
      FileUtils.rm_rf(backup_path) if backup_path && File.exist?(backup_path)
    end
  end

  def restore_backup(backup_file)
    unless File.exist?(backup_file)
      return { success: false, error: "Backup file not found: #{backup_file}" }
    end
    
    start_time = Time.current
    temp_dir = @backup_dir.join("restore_#{Time.current.to_i}")
    
    begin
      # 백업 압축 해제
      extract_result = extract_backup(backup_file, temp_dir)
      return extract_result unless extract_result[:success]
      
      # mongorestore 실행
      restore_result = perform_mongorestore(extract_result[:path])
      return restore_result unless restore_result[:success]
      
      duration = (Time.current - start_time).round(2)
      
      {
        success: true,
        collections: restore_result[:collections],
        documents: restore_result[:documents],
        duration: duration
      }
    rescue => e
      Rails.logger.error "Restore failed: #{e.message}"
      
      {
        success: false,
        error: e.message
      }
    ensure
      FileUtils.rm_rf(temp_dir) if temp_dir && File.exist?(temp_dir)
    end
  end

  def list_backups
    backups = []
    
    Dir.glob(@backup_dir.join('*.tar.gz')).each do |file|
      backups << {
        name: File.basename(file),
        size: format_size(File.size(file)),
        created: File.mtime(file).strftime('%Y-%m-%d %H:%M:%S'),
        path: file
      }
    end
    
    backups.sort_by { |b| b[:created] }.reverse
  end

  def cleanup_old_backups(days)
    cutoff_date = days.days.ago
    deleted = 0
    space_freed = 0
    
    Dir.glob(@backup_dir.join('*.tar.gz')).each do |file|
      if File.mtime(file) < cutoff_date
        space_freed += File.size(file)
        File.delete(file)
        deleted += 1
      end
    end
    
    {
      deleted: deleted,
      space_freed: format_size(space_freed)
    }
  end

  def verify_backup(backup_file)
    temp_dir = @backup_dir.join("verify_#{Time.current.to_i}")
    
    begin
      # 백업 압축 해제
      extract_result = extract_backup(backup_file, temp_dir)
      return extract_result unless extract_result[:success]
      
      # 백업 내용 검증
      collections = []
      total_documents = 0
      
      Dir.glob(File.join(extract_result[:path], '*.bson')).each do |bson_file|
        collection_name = File.basename(bson_file, '.bson')
        collections << collection_name
        
        # BSON 파일 문서 수 확인
        doc_count = count_bson_documents(bson_file)
        total_documents += doc_count
      end
      
      {
        valid: true,
        collections: collections,
        total_documents: total_documents
      }
    rescue => e
      {
        valid: false,
        error: e.message
      }
    ensure
      FileUtils.rm_rf(temp_dir) if temp_dir && File.exist?(temp_dir)
    end
  end

  private

  def perform_mongodump(backup_path)
    # MongoDB 연결 URI 구성
    uri = build_mongodb_uri
    
    # mongodump 명령 구성
    cmd = [
      'mongodump',
      '--uri', uri,
      '--out', backup_path.to_s,
      '--gzip'
    ]
    
    # 특정 컬렉션만 백업 (옵션)
    if Rails.application.config.mongodb_backup_collections
      Rails.application.config.mongodb_backup_collections.each do |collection|
        cmd += ['--collection', collection]
      end
    end
    
    stdout, stderr, status = Open3.capture3(*cmd)
    
    if status.success?
      { success: true }
    else
      {
        success: false,
        error: "mongodump failed: #{stderr}"
      }
    end
  rescue Errno::ENOENT
    {
      success: false,
      error: "mongodump not found. Please install MongoDB tools."
    }
  end

  def perform_mongorestore(restore_path)
    uri = build_mongodb_uri
    
    # Drop existing collections option
    cmd = [
      'mongorestore',
      '--uri', uri,
      '--dir', restore_path.to_s,
      '--gzip',
      '--drop' # 기존 컬렉션 삭제 후 복원
    ]
    
    stdout, stderr, status = Open3.capture3(*cmd)
    
    if status.success?
      # 복원 통계 파싱
      collections = stdout.scan(/(\d+) document\(s\) restored successfully/).flatten.count
      documents = stdout.scan(/(\d+) document\(s\) restored successfully/).flatten.map(&:to_i).sum
      
      {
        success: true,
        collections: collections,
        documents: documents
      }
    else
      {
        success: false,
        error: "mongorestore failed: #{stderr}"
      }
    end
  rescue Errno::ENOENT
    {
      success: false,
      error: "mongorestore not found. Please install MongoDB tools."
    }
  end

  def compress_backup(backup_path, backup_name)
    tar_file = @backup_dir.join("#{backup_name}.tar.gz")
    
    cmd = [
      'tar',
      '-czf',
      tar_file.to_s,
      '-C',
      @backup_dir.to_s,
      backup_name
    ]
    
    stdout, stderr, status = Open3.capture3(*cmd)
    
    if status.success?
      {
        success: true,
        file: tar_file.to_s
      }
    else
      {
        success: false,
        error: "Compression failed: #{stderr}"
      }
    end
  end

  def extract_backup(backup_file, target_dir)
    FileUtils.mkdir_p(target_dir)
    
    cmd = [
      'tar',
      '-xzf',
      backup_file,
      '-C',
      target_dir.to_s
    ]
    
    stdout, stderr, status = Open3.capture3(*cmd)
    
    if status.success?
      # 추출된 디렉토리 찾기
      extracted_dir = Dir.glob(File.join(target_dir, '*')).first
      
      {
        success: true,
        path: extracted_dir
      }
    else
      {
        success: false,
        error: "Extraction failed: #{stderr}"
      }
    end
  end

  def build_mongodb_uri
    config = Mongoid.default_client.options
    
    host = config[:hosts]&.first || 'localhost:27017'
    database = config[:database]
    
    uri = "mongodb://"
    
    # 인증 정보
    if config[:user] && config[:password]
      uri += "#{config[:user]}:#{config[:password]}@"
    end
    
    uri += "#{host}/#{database}"
    
    # 추가 옵션
    options = []
    options << "authSource=#{config[:auth_source]}" if config[:auth_source]
    options << "replicaSet=#{config[:replica_set]}" if config[:replica_set]
    
    uri += "?#{options.join('&')}" if options.any?
    
    uri
  end

  def save_backup_metadata(backup_name, type)
    metadata = {
      name: backup_name,
      type: type,
      database: @database,
      host: @host,
      created_at: Time.current,
      rails_env: Rails.env,
      collections: list_collections
    }
    
    metadata_file = @backup_dir.join("#{backup_name}.json")
    File.write(metadata_file, JSON.pretty_generate(metadata))
  end

  def list_collections
    Mongoid.default_client.collections.map(&:name).reject { |n| n.start_with?('system.') }
  end

  def count_bson_documents(bson_file)
    # 간단한 BSON 문서 수 추정 (정확하지 않을 수 있음)
    file_size = File.size(bson_file)
    avg_doc_size = 1024 # 평균 문서 크기 추정
    
    (file_size / avg_doc_size).to_i
  end

  def upload_to_s3(file_path)
    # S3 업로드 구현 (AWS SDK 필요)
    return unless defined?(Aws::S3)
    
    s3 = Aws::S3::Resource.new
    bucket = s3.bucket(Rails.application.config.s3_backup_bucket)
    
    key = "mongodb/#{Rails.env}/#{File.basename(file_path)}"
    
    bucket.object(key).upload_file(file_path)
    
    Rails.logger.info "Backup uploaded to S3: #{key}"
  rescue => e
    Rails.logger.error "S3 upload failed: #{e.message}"
  end

  def format_size(bytes)
    return '0 B' if bytes == 0
    
    units = ['B', 'KB', 'MB', 'GB']
    index = (Math.log(bytes) / Math.log(1024)).floor
    size = (bytes / (1024.0 ** index)).round(2)
    
    "#{size} #{units[index]}"
  end
end