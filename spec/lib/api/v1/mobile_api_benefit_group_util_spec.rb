require "rails_helper"
require 'lib/api/v1/support/mobile_employer_data'

RSpec.describe Api::V1::Mobile::Util::BenefitGroupUtil, dbclean: :after_each do
  include_context 'employer_data'
  Util = Api::V1::Mobile::Util

  context 'Enrollments' do

    it 'should return benefit group assignments' do
      enrollment = Util::BenefitGroupUtil.new
      enrollment.instance_variable_set(:@all_enrollments, [shop_enrollment_barista])
      enrollment.benefit_group_assignment_ids(HbxEnrollment::ENROLLED_STATUSES, HbxEnrollment::ENROLLED_STATUSES,
                                              HbxEnrollment::ENROLLED_STATUSES) { |bgas|
        expect(bgas).to be_a_kind_of Array
        expect(bgas.size).to eq 1
        expect(bgas.first).to be_a_kind_of BSON::ObjectId

        enrollment.instance_variable_set(:@ids, bgas)
        expect(enrollment.census_members.klass).to be CensusMember
      }

      expect { enrollment.benefit_group_assignment_ids(HbxEnrollment::ENROLLED_STATUSES, [], []) }.to raise_error(LocalJumpError)
      enrollment.benefit_group_assignment_ids HbxEnrollment::ENROLLED_STATUSES, [], [] do |enrolled_ids, waived_ids, terminated_ids|
        expect(enrolled_ids).to be_a_kind_of Array
        expect(enrolled_ids.size).to eq 1
        expect(enrolled_ids.pop).to be_a_kind_of BSON::ObjectId
      end
    end

  end
end