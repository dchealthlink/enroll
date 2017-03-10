require "rails_helper"
require 'lib/api/v1/support/mobile_employer_data'

RSpec.describe Api::V1::Mobile::Util::BenefitGroupUtil, dbclean: :after_each do
  include_context 'employer_data'
  Util = Api::V1::Mobile::Util

  context 'Enrollments' do

    it 'should return active employer sponsored health enrollments' do
      enrollment = Util::BenefitGroupUtil.new
      hbx_enrollment1 = HbxEnrollment.new kind: 'employer_sponsored', coverage_kind: 'health', is_active: true, submitted_at: Time.now
      hbx_enrollment2 = HbxEnrollment.new kind: 'employer_sponsored', coverage_kind: 'health', is_active: true
      hbx_enrollments = [hbx_enrollment1, hbx_enrollment2]

      enrollment.instance_variable_set(:@all_enrollments, hbx_enrollments)
      hes = enrollment.send(:_active_employer_sponsored_health_enrollments)
      expect(hes).to be_a_kind_of Array
      expect(hes.size).to eq 1
      expect(hes.pop).to be_a_kind_of HbxEnrollment
    end

    it 'should return benefit group assignments' do
      enrollment = Util::BenefitGroupUtil.new
      enrollment.instance_variable_set(:@all_enrollments, [shop_enrollment_barista])
      bgas = enrollment.send(:_bg_assignment_ids, HbxEnrollment::ENROLLED_STATUSES)
      expect(bgas).to be_a_kind_of Array
      expect(bgas.size).to eq 1
      expect(bgas.pop).to be_a_kind_of BSON::ObjectId

      expect { enrollment.benefit_group_assignment_ids(HbxEnrollment::ENROLLED_STATUSES, [], []) }.to raise_error(LocalJumpError)
      enrollment.benefit_group_assignment_ids HbxEnrollment::ENROLLED_STATUSES, [], [] do |enrolled_ids, waived_ids, terminated_ids|
        expect(enrolled_ids).to be_a_kind_of Array
        expect(enrolled_ids.size).to eq 1
        expect(enrolled_ids.pop).to be_a_kind_of BSON::ObjectId
      end
    end

  end
end