require "rails_helper"
require 'lib/api/v1/support/mobile_employer_data'
require 'lib/api/v1/support/mobile_employee_data'

RSpec.describe Api::V1::Mobile::Util::BenefitGroupAssignmentsUtil, dbclean: :after_each do
  include_context 'employer_data'
  include_context 'employee_data'
  Util = Api::V1::Mobile::Util

  context 'Benefit Group Assignments' do

    it 'should return a unique list of benefit group assignments' do
      assignment_1 = [benefit_group_assignment]
      assignment_2 = [benefit_group_assignment]

      bga_util = Util::BenefitGroupAssignmentsUtil.new assignments: (assignment_1 + assignment_2).flatten
      bgas = bga_util.unique_by_year
      expect(bgas).to be_a_kind_of Array
      expect(bgas.size).to be 1
      expect(bgas.first).to be_a_kind_of BenefitGroupAssignment
    end

  end
end