require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    # Devise modules are tested through integration tests
  end
  
  describe 'validations' do
    subject { build(:user) }
    
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:password) }
    it { should validate_length_of(:password).is_at_least(6) }
    
    it { should validate_uniqueness_of(:username).case_insensitive.allow_nil }
    it { should validate_length_of(:username).is_at_least(3).is_at_most(30).allow_nil }
    it { should allow_value('user_name').for(:username) }
    it { should allow_value('user-name').for(:username) }
    it { should allow_value('user123').for(:username) }
    it { should_not allow_value('user name').for(:username) }
    it { should_not allow_value('user@name').for(:username) }
    it { should_not allow_value('ab').for(:username) }
    
    it { should validate_inclusion_of(:role).in_array(%w[user admin moderator]) }
  end
  
  describe 'defaults' do
    it 'sets role to user by default' do
      user = User.new
      expect(user.role).to eq('user')
    end
    
    it 'generates UUID as id' do
      user = create(:user)
      expect(user.id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
    end
  end
  
  describe 'Devise modules' do
    it 'includes database_authenticatable' do
      expect(User.devise_modules).to include(:database_authenticatable)
    end
    
    it 'includes registerable' do
      expect(User.devise_modules).to include(:registerable)
    end
    
    it 'includes recoverable' do
      expect(User.devise_modules).to include(:recoverable)
    end
    
    it 'includes rememberable' do
      expect(User.devise_modules).to include(:rememberable)
    end
    
    it 'includes validatable' do
      expect(User.devise_modules).to include(:validatable)
    end
    
    it 'includes trackable' do
      expect(User.devise_modules).to include(:trackable)
    end
    
    it 'includes omniauthable' do
      expect(User.devise_modules).to include(:omniauthable)
    end
  end
  
  describe '.from_omniauth' do
    let(:auth_hash) do
      OmniAuth::AuthHash.new(
        provider: 'github',
        uid: '12345',
        info: {
          email: 'test@example.com',
          name: 'Test User'
        }
      )
    end
    
    context 'when user does not exist' do
      it 'creates a new user' do
        expect { User.from_omniauth(auth_hash) }.to change(User, :count).by(1)
      end
      
      it 'sets user attributes from auth hash' do
        user = User.from_omniauth(auth_hash)
        expect(user.email).to eq('test@example.com')
        expect(user.name).to eq('Test User')
        expect(user.provider).to eq('github')
        expect(user.uid).to eq('12345')
      end
    end
    
    context 'when user exists' do
      let!(:existing_user) { create(:user, email: 'test@example.com') }
      
      it 'does not create a new user' do
        expect { User.from_omniauth(auth_hash) }.not_to change(User, :count)
      end
      
      it 'returns the existing user' do
        user = User.from_omniauth(auth_hash)
        expect(user).to eq(existing_user)
      end
    end
  end
  
  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:user)).to be_valid
    end
    
    it 'has admin trait' do
      user = build(:user, :admin)
      expect(user.role).to eq('admin')
    end
    
    it 'has moderator trait' do
      user = build(:user, :moderator)
      expect(user.role).to eq('moderator')
    end
    
    it 'has with_avatar trait' do
      user = build(:user, :with_avatar)
      expect(user.avatar_url).to be_present
    end
    
    it 'has oauth_github trait' do
      user = build(:user, :oauth_github)
      expect(user.provider).to eq('github')
      expect(user.uid).to be_present
    end
    
    it 'has oauth_google trait' do
      user = build(:user, :oauth_google)
      expect(user.provider).to eq('google_oauth2')
      expect(user.uid).to be_present
    end
    
    it 'has tracked trait' do
      user = build(:user, :tracked)
      expect(user.sign_in_count).to be > 0
      expect(user.current_sign_in_at).to be_present
      expect(user.last_sign_in_at).to be_present
      expect(user.current_sign_in_ip).to be_present
      expect(user.last_sign_in_ip).to be_present
    end
  end
end