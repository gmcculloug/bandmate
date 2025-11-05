class UserBand < ActiveRecord::Base
  self.primary_key = 'id'

  belongs_to :user
  belongs_to :band

  validates :user_id, uniqueness: { scope: :band_id }
  validates :user, presence: true
  validates :band, presence: true
  validates :role, presence: true, inclusion: { in: ['member', 'owner'] }
  
  # Default role to 'member' if not set
  before_validation :set_default_role, on: :create
  
  # Scopes
  scope :owners, -> { where(role: 'owner') }
  scope :members, -> { where(role: 'member') }
  
  # Helper methods
  def owner?
    role == 'owner'
  end
  
  def member?
    role == 'member'
  end
  
  private
  
  def set_default_role
    self.role ||= 'member'
  end
end