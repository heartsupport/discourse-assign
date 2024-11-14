module ActivityAssigner
  SUPPORT_CATEGORIES = [67, 77, 85, 87, 88, 89, 102, 106].freeze
  def self.process_topic(topic)
    return unless SUPPORT_CATEGORIES.include?(topic.category_id)

    # find two support users and assign the topic to the
    #  query the database for the two users
    sql =
      "
        WITH assigned_users AS (
          SELECT assigned_to_id, COUNT(assigned_to_id) as assigned_count
          FROM assignments
          WHERE created_at >= CURRENT_DATE - INTERVAL '7 Days'
          GROUP BY assigned_to_id
        )

        SELECT user_id
        FROM group_users
        WHERE group_id = 1 AND
        user_id NOT IN (SELECT assigned_to_id FROM assigned_users)
        ORDER BY RANDOM()
        LIMIT 2
      "
    group_users = ActiveRecord::Base.connection.execute(sql)
    group_users.each do |group_user|
      system_user = User.find_by(username: "system")
      user = User.find(group_user["user_id"])
      # assign the topic to the user
      assign = DiscourseAssign::Assigner.new(topic, system_user).assign(user)
      unless assign[:success]
        Rails.logger.error("Failed to assign topic #{topic.id} to #{user.id}")
      end
    end
  end

  def self.process_post(post)
    # if the replier is assined to the topic, unasign the user
    assignment =
      Assignment.find_by(topic_id: post.topic_id, assigned_to_id: post.user_id)
    if assignment
      system_user = User.find_by(username: "system")
      DiscourseAssign::Assigner.new(post.topic, system_user).unassign
    end
  end
end
