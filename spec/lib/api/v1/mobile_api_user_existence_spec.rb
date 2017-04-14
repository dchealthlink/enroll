require 'rails_helper'
require 'lib/api/v1/support/mobile_user_existence_data'
require 'lib/api/v1/support/mobile_individual_data'

RSpec.describe Api::V1::Mobile::UserExistence, dbclean: :after_each do
  include_context 'user_existence_data'
  include_context 'individual_data'

  Mobile = Api::V1::Mobile

  context 'User Existence Check' do

    it 'should handle the case where the user does not exist' do
      user_existence = Mobile::UserExistence.new body: request_json
      response = JSON.parse user_existence.check_user_existence
      expect(response).to be_a_kind_of Hash
      expect(response).to include('error')
      expect(response['error']).to eq Api::V1::Mobile::UserExistence::USER_DOES_NOT_EXIST
    end

    it 'should handle the case where the ssn is empty' do
      hash = JSON.parse request_json
      hash['person_demographics']['ssn'] = ''
      user_existence = Mobile::UserExistence.new body: hash.to_json
      response = JSON.parse user_existence.check_user_existence
      expect(response).to be_a_kind_of Hash
      expect(response).to include('error')
      expect(response['error']).to eq Api::V1::Mobile::UserExistence::SSN_EMPTY
    end

    it 'should handle the case where the user with the same SSN already exists' do
      user = FactoryGirl.create :user, :with_consumer_role
      hash = JSON.parse request_json
      hash['person_demographics']['ssn'] = user.person.ssn
      user_existence = Mobile::UserExistence.new body: hash.to_json
      response = JSON.parse user_existence.check_user_existence
      expect(response).to include('error')
      expect(response['error']).to eq 'The social security number you entered is affiliated with another account.'
    end

    it ' should handle the case where the user does exist ' do
      hash = JSON.parse request_json
      hash['person_demographics']['ssn'] = person_no_user.ssn
      user_existence = Mobile::UserExistence.new body: hash.to_json
      response = JSON.parse user_existence.check_user_existence
      expect(response).to be_a_kind_of Hash
      expect(response).to include('primary_applicant','employers')

      primary_applicant = response['primary_applicant']
      expect(primary_applicant).to include('id','user_id','first_name','last_name')

      employers = response['employers']
      expect(employers).to be_a_kind_of Array

      employer = employers.first
      expect(employer).to be_a_kind_of Hash
      expect(employer).to include('employer','broker')
      expect(employer['employer']).to include('id','legal_name','phone')
      expect(employer['broker']).to include('id','legal_name','phone')
    end

  end
end