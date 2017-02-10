require "rails_helper"
require 'lib/api/v1/support/mobile_individual_data'

RSpec.describe Api::V1::Mobile::IndividualUtil, dbclean: :after_each do
  include_context 'individual_data'

  context 'Individuals' do

    it 'should return the individual details' do
      allow(person).to receive(:broker_agency_staff_roles).and_return([broker_agency_staff_role])
      allow(census_employee).to receive(:census_dependents).and_return([census_dependent])
      allow(benefit_group_assignment).to receive(:hbx_enrollments).and_return([hbx_enrollment])

      individual = Api::V1::Mobile::IndividualUtil.new person: person
      output = individual.build_individual_json
      expect(output).to include('first_name', 'middle_name', 'last_name', 'name_suffix', 'date_of_birth', 'ssn_masked',
                                'gender', 'id', 'employments')

      employment = output['employments'].first
      expect(employment).to include('employer_profile_id', 'employer_name', 'hired_on', 'is_business_owner')

      enrollment = output['enrollments'].first
      expect(enrollment).to include('employer_profile_id', 'start_on', 'health', 'dental')

      health = enrollment['health']
      expect(health).to include('status', 'employer_contribution', 'employee_cost', 'total_premium', 'plan_name',
                                'plan_type', 'metal_level', 'benefit_group_name')

      dependent = output['dependents'].first
      expect(dependent).to include('first_name', 'middle_name', 'last_name', 'name_suffix', 'date_of_birth', 'ssn_masked',
                                   'gender', 'id', 'relationship')
    end

  end

end