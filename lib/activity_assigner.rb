module ActivityAssigner
  SUPPORT_CATEGORIES = [67, 77, 85, 87, 88, 89, 102, 106, 4].freeze
  ASSIGNMENT_GROUP = [86, 41]

  def self.process_post(post)
    if post.is_first_post? && post.topic.category_id.in?(SUPPORT_CATEGORIES)
      assign_support_user(post.topic) if SiteSetting.assign_enabled?
    end

    # if post is a reply from assigned user, unassign the topic and re-assign
    # to another user
    if !post.is_first_post? && post.topic.category_id.in?(SUPPORT_CATEGORIES)
      if Assignment
    end
  end

  def self.process_topic_tag(topic_tag)
    supported_tag = Tag.find_or_create_by(name: "Supported")

    return unless topic_tag.topic.category_id.in?(SUPPORT_CATEGORIES)

    return unless topic_tag.tag_id == supported_tag.id

    # find all users assigned to the topic]
    if topic_tag.topic.assignment.present?
      system_user = User.find_by(username: "system")
      assigner = Assigner.new(topic_tag.topic, system_user)
      assigner.unassign
    end
  end

  def self.assign_support_user(topic)
    system_user = User.find_by(username: "system")
    # assign to another user
    sql =
      "
            WITH assigned_users AS (
              SELECT assigned_to_id, COUNT(assigned_to_id) as assigned_count
              FROM assignments
              WHERE created_at >= CURRENT_DATE - INTERVAL '7 Days'
              GROUP BY assigned_to_id
              HAVING COUNT(assigned_to_id) >= 4
            )

            SELECT user_id
            FROM group_users
            WHERE group_id IN (?) AND
            user_id NOT IN (SELECT assigned_to_id FROM assigned_users)
            ORDER BY RANDOM()
            LIMIT 1
          "
    # results = ActiveRecord::Base.connection.execute(sql)
    results =
      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.send(:sanitize_sql_array, [sql, group_ids])
      )
    return unless results.count > 0
    user = results&.first
    user = User.find(user["user_id"])

    assign = Assigner.new(topic, system_user).assign(user)
    unless assign[:success]
      Rails.logger.error(
        "========>  Failed to assign topic #{topic.id} to #{user.id} reason: #{assign} ========"
      )
    end

    return user
  end
end
