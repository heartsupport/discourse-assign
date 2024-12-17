module ActivityAssigner
  SUPPORT_CATEGORIES = [67, 77, 85, 87, 88, 89, 102, 106, 4].freeze
  def self.process_post(post)
    # Rails.logger.info("****** Processing Post ******")
    # Rails.logger.info("****** First Post #{post.is_first_post?} ******")
    # Rails.logger.info(
    #   "****** In Cat #{post.topic.category_id.in?(SUPPORT_CATEGORIES)} ******"
    # )
    # Rails.logger.info(
    #   "****** Assignment present #{post.topic.assignment.present?} ******"
    # )
    # Rails.logger.info(
    #   "****** same user #{post.topic.assignment.assigned_to_id == post.user_id} ******"
    # )
    # topic = post.topic
    # Rails.logger.info(
    #   "========> Topic #{topic.id} & Category #{topic.category_id} ========="
    # )
    if post.is_first_post? && post.topic.category_id.in?(SUPPORT_CATEGORIES)
      # Rails.logger.info("========> First post #{post.id} =========")
      # find two support users and assign the topic to the
      #  query the database for the two users
      assign_swat_user(post.topic) if SiteSetting.assign_enabled?
    end

    # if !post.is_first_post? && topic.category_id.in?(SUPPORT_CATEGORIES)
    #   # reload the topic to get the latest data
    #   post.topic.reload

    #   # find all users assigned to the topic]
    #   if post.topic.assignment.present? &&
    #        post.topic.assignment.assigned_to_id == post.user_id
    #     # Rails.logger.info("========> UnAssigngin Post #{post.id} =========")
    #     system_user = User.find_by(username: "system")
    #     target = Topic.find(post.topic_id)
    #     assigner = Assigner.new(target, system_user)
    #     assigner.unassign

    #     # Rails.logger.info(
    #     #   "========> Unassigned Topic #{topic.id} Response: #{assigner} ========="
    #     # )

    #     assign_swat_user(topic)
    #   end
    # end
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

  def self.assign_swat_user(topic)
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
            WHERE group_id IN (54,41) AND
            user_id NOT IN (SELECT assigned_to_id FROM assigned_users)
            ORDER BY RANDOM()
            LIMIT 1
          "
    results = ActiveRecord::Base.connection.execute(sql)
    return unless results.count > 0
    user = results&.first
    user = User.find(user["user_id"])
    # Rails.logger.info(
    #   "========> Assigning Topic #{topic} from SWAT Assigner ========="
    # )

    assign = Assigner.new(topic, system_user).assign(user)
    unless assign[:success]
      Rails.logger.error(
        "========>  Failed to assign topic #{topic.id} to #{user.id} reason: #{assign} ========"
      )
    end

    return user
  end
end
