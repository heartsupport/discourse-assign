require "rails_helper"

RSpec.describe ActivityAssigner do
  before do
    SiteSetting.assign_enabled = true
    SiteSetting.enable_assign_status = true
  end

  before(:each) do
    stub_request(
      :post,
      "https://porter.heartsupport.com/webhooks/supplier"
    ).to_return(status: 200, body: "", headers: {})
    stub_request(
      :post,
      "https://porter.heartsupport.com/twilio/discourse_webhook"
    ).to_return(status: 200, body: "", headers: {})
    stub_request(
      :post,
      "https://porter.heartsupport.com/webhooks/supplier"
    ).to_return(status: 200, body: "", headers: {})
    stub_request(
      :get,
      %r{https\://porter.heartsupport.com/api/sentiment}
    ).to_return(status: 200, body: "", headers: {})
    stub_request(
      :post,
      "https://porter.heartsupport.com/webhooks/topic_tags"
    ).to_return(status: 200, body: "", headers: {})
  end

  describe "assigning a user to a topic" do
    let(:group) { Fabricate(:group, id: 86) }
    let(:category) { Fabricate(:category, id: 67) }
    let(:topic) { Fabricate(:topic, category: category) }
    let(:user) { Fabricate(:user) }
    let(:assigner) { instance_double(Assigner) }
    let(:system_user) { User.find_by(username: "system") }
    let(:support_user) { Fabricate(:user) }
    let!(:group_user) do
      Fabricate(:group_user, group: group, user: support_user)
    end
    let(:post) { instance_double(Post) }

    before do
      SiteSetting.assign_allowed_on_groups = "#{group.id}"
      allow(post).to receive(:is_first_post?).and_return(true)
      allow(User).to receive(:find_by).with(username: "system").and_return(
        system_user
      )
      allow(post).to receive(:topic).and_return(topic)
      allow(topic).to receive(:category_id).and_return(category.id)
      allow(post).to receive(:is_first_post?).and_return(true)
    end

    it "assigns a support user to the topic" do
      # create a post
      expect {
        post = Fabricate(:post, topic: topic, user: user)
        post.save!
      }.to change { Assignment.count }.by(1)

      expect(post.topic.reload&.assignment&.assigned_to).to eq(support_user)
    end

    it "unassigns a user from the topic when they reply" do
      post = Fabricate(:post, topic: topic, user: user)
      post.save!

      expect(post.topic.reload&.assignment&.assigned_to).to eq(support_user)

      # create a second group user
      user = Fabricate(:user)
      group_user = Fabricate(:group_user, group: group, user: user)
      group_user.save!

      reply = Fabricate(:post, topic: topic, user: support_user)
      reply.save!

      # expect the user to be unassigned
      expect(reply.topic.reload&.assignment&.assigned_to).to eq(support_user)
      expect(reply.topic.reload.assignment.active).to be_falsey
    end

    it 'removes assignment when the topic is tagged with "Supported"' do
      post = Fabricate(:post, topic: topic, user: user)
      post.save!
      post.topic.tags << Tag.find_or_create_by(name: "Supported")
      post.topic.save!

      expect(post.topic.reload.assignment.active).to be_falsey
    end
  end
end
