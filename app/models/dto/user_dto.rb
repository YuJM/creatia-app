# frozen_string_literal: true

module Dto
  # UserDto - User 데이터 전송 객체
  class UserDto < BaseDto
    attribute :id, Types::String
    attribute :name, Types::String
    attribute :email, Types::String

    attribute? :avatar_url, Types::String.optional
    attribute? :role, Types::String.optional
    attribute? :department, Types::String.optional
    attribute? :position, Types::String.optional
    attribute? :phone, Types::String.optional

    attribute? :created_at, Types::DateTime.optional
    attribute? :updated_at, Types::DateTime.optional

    # UserSnapshot에서 생성
    def self.from_snapshot(snapshot)
      return nil unless snapshot

      new(
        id: snapshot.user_id,
        name: snapshot.name,
        email: snapshot.email,
        avatar_url: snapshot.avatar_url,
        role: snapshot.role,
        department: snapshot.department,
        position: snapshot.position
      )
    end

    # User 모델에서 생성
    def self.from_user(user)
      return nil unless user

      new(
        id: user.id.to_s,
        name: user.name,
        email: user.email,
        avatar_url: user.avatar_url,
        role: user.role,
        department: user.respond_to?(:department) ? user.department : nil,
        position: user.respond_to?(:position) ? user.position : nil
      )
    end

    # User 모델에서 생성 (BaseDto 호환성)
    def self.from_model(user, enriched_data = {})
      from_user(user)
    end

    # Hash 데이터에서 생성 (캐시 복원용)
    def self.from_data(data)
      return nil unless data.is_a?(Hash)

      new(
        id: data[:id] || data["id"],
        name: data[:name] || data["name"],
        email: data[:email] || data["email"],
        avatar_url: data[:avatar_url] || data["avatar_url"],
        role: data[:role] || data["role"],
        department: data[:department] || data["department"],
        position: data[:position] || data["position"],
        phone: data[:phone] || data["phone"],
        created_at: data[:created_at] || data["created_at"],
        updated_at: data[:updated_at] || data["updated_at"]
      )
    end

    def initials
      name.split.map(&:first).join.upcase[0..1]
    end

    def display_name
      name.presence || email.split("@").first
    end
  end
end