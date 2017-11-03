require 'rails_helper'
require 'lib/api/v1/support/mobile_individual_data'

RSpec.describe Api::V1::Mobile::UserExistence, dbclean: :after_each do
  include_context 'individual_data'

  Mobile = Api::V1::Mobile

  context 'User Existence Check' do

    it 'should handle the case where the user does not exist' do
      user_existence = Mobile::Ridp::RidpUserExistence.new pii_data: {ssn: '111222333'}
      response = JSON.parse user_existence.check_user_existence
      expect(response).to be_a_kind_of Hash
      expect(response).to include('ridp_verified', 'user_found_in_enroll')
      expect(response['ridp_verified']).to be true
      expect(response['user_found_in_enroll']).to be false
    end

    it 'should handle the case where the ssn is empty' do
      user_existence = Mobile::Ridp::RidpUserExistence.new pii_data: {ssn: '', first_name: 'John',
                                                                      last_name: 'Smith30', birth_date: '19720404'}
      response = JSON.parse user_existence.check_user_existence
      expect(response).to be_a_kind_of Hash
      expect(response).to include('ridp_verified', 'token', 'user_found_in_enroll')
      expect(response['ridp_verified']).to be true
      expect(response['user_found_in_enroll']).to be false
    end

    it 'should handle the case where the user with the same SSN already exists' do
      user = FactoryGirl.create :user, :with_consumer_role
      user_existence = Mobile::Ridp::RidpUserExistence.new pii_data: {ssn: user.person.ssn}
      response = JSON.parse user_existence.check_user_existence
      expect(response).to include('ridp_verified', 'user_found_in_enroll')
      expect(response['ridp_verified']).to eq true
      expect(response['user_found_in_enroll']).to be true
    end

    it ' should handle the case where the user does exist ' do
      user_existence = Mobile::Ridp::RidpUserExistence.new pii_data: {ssn: person_no_user.ssn}
      response = JSON.parse user_existence.check_user_existence
      expect(response).to be_a_kind_of Hash
      expect(response).to include('ridp_verified', 'token', 'primary_applicant', 'employers')

      primary_applicant = response['primary_applicant']
      expect(primary_applicant).to include('id', 'user_id', 'first_name', 'last_name')

      employers = response['employers']
      expect(employers).to be_a_kind_of Array

      employer = employers.first
      expect(employer).to be_a_kind_of Hash
      expect(employer).to include('employer', 'broker')
      expect(employer['employer']).to include('id', 'legal_name', 'phone')
      expect(employer['broker']).to include('id', 'organization_legal_name', 'legal_name', 'phone')
    end

  end
end