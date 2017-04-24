require "rails_helper"
require 'lib/api/v1/support/mobile_individual_data'

RSpec.describe Api::V1::Mobile::Util::InsuredUtil, dbclean: :after_each do
  include_context 'individual_data'
  Util = Api::V1::Mobile::Util

  context 'Individuals' do

    it 'should return the individual employee details' do
      allow(person).to receive(:primary_family).and_return(FactoryGirl.create(:individual_market_family_with_spouse))

      insured_employee = Api::V1::Mobile::Insured::InsuredEmployee.new
      allow(insured_employee).to receive(:ins_enrollments).and_return([hbx_enrollment])

      individual = Util::InsuredUtil.new person: person
      output = individual.build_response
      expect(output).to include('first_name', 'middle_name', 'last_name', 'name_suffix', 'date_of_birth', 'ssn_masked',
                                'gender', 'id', 'employments', 'addresses')

      employment = output['employments'].first
      expect(employment).to include('employer_profile_id', 'employer_name', 'hired_on', 'is_business_owner')

      enrollment = output['enrollments'].last
      expect(enrollment).to include('employer_profile_id', 'start_on', 'health', 'dental')

      addresses = output['addresses'].first
      expect(addresses).to include('kind', 'address_1', 'address_2', 'city', 'county', 'state', 'location_state_code', 'zip', 'country_name')

      health = enrollment['health']
      expect(health).to include('status', 'employer_contribution', 'employee_cost', 'total_premium', 'plan_name',
                                'plan_type', 'metal_level', 'carrier_name', 'summary_of_benefits_url')

      dependent = output['dependents'].first
      expect(dependent).to include('first_name', 'middle_name', 'last_name', 'name_suffix', 'date_of_birth', 'ssn_masked',
                                   'gender', 'id', 'relationship')
    end

    it 'should return the individual non-employee details' do
      individual = Util::InsuredUtil.new person: non_employee_individual_person
      output = individual.build_response
      expect(output).to include('first_name', 'middle_name', 'last_name', 'name_suffix', 'date_of_birth', 'ssn_masked',
                                'gender', 'id', 'employments', 'addresses')

      employment = output['employments']
      expect(employment).to be_a_kind_of Array
      expect(employment.size).to eq 0

      enrollment = output['enrollments'].last
      expect(enrollment).to include('health', 'dental')

      addresses = output['addresses'].first
      expect(addresses).to include('kind', 'address_1', 'address_2', 'city', 'county', 'state', 'location_state_code', 'zip', 'country_name')

      health = enrollment['health']
      expect(health).to include('status', 'total_premium', 'plan_name', 'plan_type', 'metal_level', 'benefit_group_name',
                                'elected_aptc_pct', 'applied_aptc_amount_in_cents', 'carrier_name', 'summary_of_benefits_url')

      dependent = output['dependents'].first
      expect(dependent).to include('first_name', 'middle_name', 'last_name', 'name_suffix', 'date_of_birth', 'ssn_masked',
                                   'gender', 'id', 'relationship')
    end

  end

end