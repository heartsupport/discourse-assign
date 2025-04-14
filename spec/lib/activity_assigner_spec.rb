require "rails_helper"

RSpec.describe ActivityAssigner do
  before do
    SiteSetting.assign_enabled = true
    SiteSetting.enable_assign_status = true
  end

  describe "assigning a user to a topic" do
    let(:category) { Fabricate(:category) }
    let(:topic) { Fabricate(:topic, category: category) }
    let(:post) { Fabricate(:post, topic: topic) }
    let(:user) { Fabricate(:user) }

    before do
      # SiteSetting.assign_enabled = true
      # SiteSetting.enable_assign_status = true
      # SiteSetting.assign_group_id = 1
      # SiteSetting.assign_group_name = "Support"
      # SiteSetting.assign_group_description = "Support group"
      # SiteSetting.assign_group_color = "#000000"
      # SiteSetting.assign_group_icon = "fa-user"
    end

    it "assigns a user to the topic" do
      expect(ActivityAssigner).to receive(:assign_support_user).with(topic)
      expect(DiscourseAssign::Assigner).to receive(:new).with(topic, user)
      expect { ActivityAssigner.process_post(post) }.to change {
        Assignment.count
      }.by(1)
    end

    it "unassigns a user from the topic when they reply" do
    end
  end
end
