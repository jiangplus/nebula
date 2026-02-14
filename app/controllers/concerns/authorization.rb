module Authorization
  extend ActiveSupport::Concern

  included do
    helper_method :can_access_collection?, :can_edit_collection?, :can_delete_collection?,
                 :can_access_post?, :can_edit_post?, :can_delete_post? if respond_to?(:helper_method)
  end

  def can_access_collection?(collection)
    return true if collection.public?
    return true if current_user&.id == collection.owner_id
    return true if current_user&.is_admin?
    false
  end

  def can_edit_collection?(collection)
    return true if current_user&.id == collection.owner_id
    return true if current_user&.is_admin?
    false
  end

  def can_delete_collection?(collection)
    can_edit_collection?(collection)
  end

  def can_access_post?(post)
    case post.privacy
    when 0 # Public
      true
    when 1 # Friends only
      current_user&.id == post.owner_id
    when 2 # Private
      current_user&.id == post.owner_id
    else
      false
    end
  end

  def can_edit_post?(post)
    return true if current_user&.id == post.owner_id
    return true if current_user&.is_admin?
    false
  end

  def can_delete_post?(post)
    can_edit_post?(post)
  end
end
