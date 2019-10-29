# name: discourse-user-scores
# about: add user scores calculated from DirectoryItem stats
# version: 1.0.0
# authors: @orlando
# url: https://github.com/orlando/discourse-user-scores

enabled_site_setting :user_scores_enabled

after_initialize do
  # Monkey patch ActiveModel::Serializer to allow us
  # reload child serializers attributes after parent is modified
  class ::ActiveModel::Serializer
    def self.reload
      self._attributes = _attributes.merge(superclass._attributes)
    end
  end

  add_to_serializer(:basic_user, :score) do
    # Cache the score for 1 day since doing
    # this for every user is expensive
    cache_key = "DirectoryItem-user-#{user.id}"
    stats = Rails.cache.fetch("#{cache_key}/all", expires_in: 1.day) do
      DirectoryItem.where(user_id: user.id, period_type: 1).first
    end

    return 0 if stats.nil?

    like_received_points = stats.likes_received * SiteSetting.user_scores_like_received_points
    like_given_points = stats.likes_given * SiteSetting.user_scores_like_given_points
    topic_points = stats.topic_count * SiteSetting.user_scores_topic_points
    topic_entered_points = stats.topics_entered * SiteSetting.user_scores_topic_entered_points
    post_points = stats.post_count * SiteSetting.user_scores_post_points
    post_read_points = stats.posts_read * SiteSetting.user_scores_post_read_points
    day_visited_points = stats.days_visited * SiteSetting.user_scores_day_visited_points

    [
      like_received_points,
      like_given_points,
      topic_points,
      topic_entered_points,
      post_points,
      post_read_points,
      day_visited_points
    ].sum
  end

  BasicUserSerializer.descendants.each(&:reload)
end
