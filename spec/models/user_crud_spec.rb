require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'CRUD operations' do
    let(:valid_attributes) do
      {
        email: Faker::Internet.unique.email,
        password: 'password123',
        username: Faker::Internet.unique.username(specifier: 3..20, separators: %w[_ -]),
        name: Faker::Name.name,
        bio: Faker::Lorem.paragraph,
        role: 'user'
      }
    end
    
    let(:invalid_attributes) do
      {
        email: 'invalid_email',
        password: '123',
        username: 'ab',
        role: 'invalid_role'
      }
    end
    
    describe 'CREATE' do
      context 'with valid attributes' do
        it 'creates a new user with UUID' do
          user = User.create!(valid_attributes)
          expect(user).to be_persisted
          expect(user.id).to be_a(String)
          expect(user.id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
        end
        
        it 'encrypts the password' do
          user = User.create!(valid_attributes)
          expect(user.encrypted_password).not_to eq('password123')
          expect(user.encrypted_password).to be_present
        end
        
        it 'sets default role' do
          attributes = valid_attributes.except(:role)
          user = User.create!(attributes)
          expect(user.role).to eq('user')
        end
        
        it 'creates user via OAuth' do
          auth_hash = OmniAuth::AuthHash.new(
            provider: 'github',
            uid: '12345',
            info: {
              email: Faker::Internet.unique.email,
              name: Faker::Name.name
            }
          )
          
          user = User.from_omniauth(auth_hash)
          expect(user).to be_persisted
          expect(user.provider).to eq('github')
          expect(user.uid).to eq('12345')
        end
      end
      
      context 'with invalid attributes' do
        it 'fails with invalid email' do
          user = User.new(invalid_attributes)
          expect(user).not_to be_valid
          expect(user.errors[:email]).to be_present
        end
        
        it 'fails with short password' do
          user = User.new(invalid_attributes)
          expect(user).not_to be_valid
          expect(user.errors[:password]).to be_present
        end
        
        it 'fails with short username' do
          user = User.new(invalid_attributes)
          expect(user).not_to be_valid
          expect(user.errors[:username]).to be_present
        end
        
        it 'fails with invalid role' do
          user = User.new(valid_attributes.merge(role: 'superadmin'))
          expect(user).not_to be_valid
          expect(user.errors[:role]).to be_present
        end
        
        it 'fails with duplicate email' do
          User.create!(valid_attributes)
          duplicate_user = User.new(valid_attributes)
          expect(duplicate_user).not_to be_valid
          expect(duplicate_user.errors[:email]).to include('has already been taken')
        end
        
        it 'fails with duplicate username' do
          User.create!(valid_attributes)
          duplicate_user = User.new(valid_attributes.merge(email: Faker::Internet.unique.email))
          expect(duplicate_user).not_to be_valid
          expect(duplicate_user.errors[:username]).to include('has already been taken')
        end
      end
    end
    
    describe 'READ' do
      let!(:user) { User.create!(valid_attributes) }
      
      it 'finds user by id' do
        found_user = User.find(user.id)
        expect(found_user).to eq(user)
      end
      
      it 'finds user by email' do
        found_user = User.find_by(email: user.email)
        expect(found_user).to eq(user)
      end
      
      it 'finds user by username' do
        found_user = User.find_by(username: user.username)
        expect(found_user).to eq(user)
      end
      
      it 'finds users by role' do
        admin_user = User.create!(valid_attributes.merge(
          email: Faker::Internet.unique.email,
          username: Faker::Internet.unique.username(specifier: 3..20, separators: %w[_ -]),
          role: 'admin'
        ))
        
        users = User.where(role: 'user')
        admins = User.where(role: 'admin')
        
        expect(users).to include(user)
        expect(users).not_to include(admin_user)
        expect(admins).to include(admin_user)
        expect(admins).not_to include(user)
      end
      
      it 'returns all users' do
        user2 = User.create!(valid_attributes.merge(
          email: Faker::Internet.unique.email,
          username: Faker::Internet.unique.username(specifier: 3..20, separators: %w[_ -])
        ))
        
        all_users = User.all
        expect(all_users).to include(user, user2)
        expect(all_users.count).to eq(2)
      end
    end
    
    describe 'UPDATE' do
      let!(:user) { User.create!(valid_attributes) }
      
      context 'with valid attributes' do
        it 'updates email' do
          new_email = Faker::Internet.unique.email
          user.update!(email: new_email)
          user.reload
          expect(user.email).to eq(new_email)
        end
        
        it 'updates username' do
          new_username = Faker::Internet.unique.username(specifier: 3..20, separators: %w[_ -])
          user.update!(username: new_username)
          user.reload
          expect(user.username).to eq(new_username)
        end
        
        it 'updates password' do
          old_encrypted = user.encrypted_password
          user.update!(password: 'newpassword123')
          user.reload
          expect(user.encrypted_password).not_to eq(old_encrypted)
          expect(user.valid_password?('newpassword123')).to be true
        end
        
        it 'updates role' do
          user.update!(role: 'admin')
          user.reload
          expect(user.role).to eq('admin')
        end
        
        it 'updates profile information' do
          new_name = Faker::Name.name
          new_bio = Faker::Lorem.paragraph
          new_avatar = Faker::Avatar.image
          
          user.update!(
            name: new_name,
            bio: new_bio,
            avatar_url: new_avatar
          )
          user.reload
          
          expect(user.name).to eq(new_name)
          expect(user.bio).to eq(new_bio)
          expect(user.avatar_url).to eq(new_avatar)
        end
        
        it 'tracks sign in information' do
          user.update!(
            sign_in_count: 5,
            current_sign_in_at: Time.current,
            last_sign_in_at: 1.day.ago,
            current_sign_in_ip: '192.168.1.1',
            last_sign_in_ip: '192.168.1.2'
          )
          user.reload
          
          expect(user.sign_in_count).to eq(5)
          expect(user.current_sign_in_at).to be_present
          expect(user.last_sign_in_at).to be_present
          expect(user.current_sign_in_ip).to eq('192.168.1.1')
          expect(user.last_sign_in_ip).to eq('192.168.1.2')
        end
      end
      
      context 'with invalid attributes' do
        it 'fails to update with invalid email' do
          expect { user.update!(email: 'invalid') }.to raise_error(ActiveRecord::RecordInvalid)
          user.reload
          expect(user.email).to eq(valid_attributes[:email])
        end
        
        it 'fails to update with duplicate email' do
          other_user = User.create!(valid_attributes.merge(
            email: Faker::Internet.unique.email,
            username: Faker::Internet.unique.username(specifier: 3..20, separators: %w[_ -])
          ))
          
          expect { user.update!(email: other_user.email) }.to raise_error(ActiveRecord::RecordInvalid)
          user.reload
          expect(user.email).to eq(valid_attributes[:email])
        end
        
        it 'fails to update with invalid role' do
          expect { user.update!(role: 'superuser') }.to raise_error(ActiveRecord::RecordInvalid)
          user.reload
          expect(user.role).to eq('user')
        end
      end
    end
    
    describe 'DELETE' do
      let!(:user) { User.create!(valid_attributes) }
      
      it 'deletes the user' do
        expect { user.destroy }.to change(User, :count).by(-1)
      end
      
      it 'removes user from database' do
        user_id = user.id
        user.destroy
        expect { User.find(user_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
      
      it 'can delete multiple users' do
        user2 = User.create!(valid_attributes.merge(
          email: Faker::Internet.unique.email,
          username: Faker::Internet.unique.username(specifier: 3..20, separators: %w[_ -])
        ))
        user3 = User.create!(valid_attributes.merge(
          email: Faker::Internet.unique.email,
          username: Faker::Internet.unique.username(specifier: 3..20, separators: %w[_ -])
        ))
        
        expect { User.destroy_all }.to change(User, :count).from(3).to(0)
      end
      
      it 'can delete users by condition' do
        admin = User.create!(valid_attributes.merge(
          email: Faker::Internet.unique.email,
          username: Faker::Internet.unique.username(specifier: 3..20, separators: %w[_ -]),
          role: 'admin'
        ))
        
        expect { User.where(role: 'user').destroy_all }.to change(User, :count).by(-1)
        expect(User.find(admin.id)).to eq(admin)
      end
    end
    
    describe 'UUID validation' do
      it 'generates unique UUIDs for each user' do
        user1 = User.create!(valid_attributes)
        user2 = User.create!(valid_attributes.merge(
          email: Faker::Internet.unique.email,
          username: Faker::Internet.unique.username(specifier: 3..20, separators: %w[_ -])
        ))
        
        expect(user1.id).not_to eq(user2.id)
        expect(user1.id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
        expect(user2.id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
      end
      
      it 'maintains UUID after update' do
        user = User.create!(valid_attributes)
        original_id = user.id
        
        user.update!(name: 'New Name')
        user.reload
        
        expect(user.id).to eq(original_id)
      end
    end
  end
end