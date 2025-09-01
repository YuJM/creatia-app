# frozen_string_literal: true

require 'dry-struct'
require 'dry-monads'

# Task 담당자 Value Object
class TaskAssignee < Dry::Struct
  include Dry::Monads[:maybe]
  
  transform_keys(&:to_sym)

  attribute? :id, Types::OptionalID
  attribute? :name, Types::String.optional
  attribute? :email, Types::OptionalEmail
  attribute? :avatar_url, Types::String.optional

  def self.unassigned
    new(id: nil, name: '미할당', email: nil, avatar_url: nil)
  end

  def self.from_user_id(user_id, organization)
    return unassigned unless user_id

    user = User.cached_find(user_id)
    return unassigned unless user

    new(
      id: user.id.to_s,
      name: user.name || user.email,
      email: user.email,
      avatar_url: user.avatar_url
    )
  rescue StandardError
    unassigned
  end

  def self.from_user(user)
    return unassigned unless user

    new(
      id: user.id.to_s,
      name: user.name || user.email,
      email: user.email,
      avatar_url: user.avatar_url
    )
  end

  def assigned?
    id.present?
  end

  def unassigned?
    !assigned?
  end

  def display_name
    name || email || '미할당'
  end

  def initials
    return '?' if unassigned?
    
    if name.present?
      name.split.map(&:first).join.upcase[0..1]
    elsif email.present?
      email[0..1].upcase
    else
      '??'
    end
  end

  def to_h
    {
      id: id,
      name: name,
      email: email,
      avatar_url: avatar_url,
      display_name: display_name,
      initials: initials,
      assigned: assigned?
    }.compact
  end

  def ==(other)
    other.is_a?(self.class) && id == other.id
  end

  alias eql? ==

  def hash
    id.hash
  end
end