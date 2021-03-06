# == Schema Information
#
# Table name: keys
#
#  id          :integer          not null, primary key
#  user_id     :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  key         :text
#  title       :string(255)
#  type        :string(255)
#  fingerprint :string(255)
#

require 'digest/md5'

class Key < ActiveRecord::Base
  include Gitlab::Popen

  belongs_to :user

  attr_accessible :key, :title

  before_validation :strip_white_space, :generate_fingerpint

  validates :title, presence: true, length: { within: 0..255 }
  validates :key, presence: true, length: { within: 0..5000 }, format: { with: /\A(ssh|ecdsa)-.*\Z/ }, uniqueness: true
  validates :fingerprint, uniqueness: true, presence: { message: 'cannot be generated' }

  delegate :name, :email, to: :user, prefix: true

  def strip_white_space
    self.key = key.strip unless key.blank?
  end

  # projects that has this key
  def projects
    user.authorized_projects
  end

  def shell_id
    "key-#{id}"
  end

  private

  def generate_fingerpint
    self.fingerprint = nil
    return unless key.present?

    cmd_status = 0
    cmd_output = ''
    Tempfile.open('gitlab_key_file') do |file|
      file.puts key
      file.rewind
      cmd_output, cmd_status = popen(%W(ssh-keygen -lf #{file.path}), '/tmp')
    end

    if cmd_status.zero?
      cmd_output.gsub /([\d\h]{2}:)+[\d\h]{2}/ do |match|
        self.fingerprint = match
      end
    end
  end
end
