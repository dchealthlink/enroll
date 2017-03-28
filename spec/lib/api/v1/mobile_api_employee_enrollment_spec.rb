require "rails_helper"
require 'lib/api/v1/support/mobile_employer_data'

RSpec.describe Api::V1::Mobile::Enrollment::EmployeeEnrollment, dbclean: :after_each do
  include_context 'employer_data'
  Util = Api::V1::Mobile::Util

  context 'Enrollments' do

    it 'should return employee enrollments' do
      assignments = [benefit_group_assignment, benefit_group_assignment]
      grouped_bga_enrollments = [hbx_enrollment].group_by { |x| x.benefit_group_assignment_id.to_s }
      enrollments = Api::V1::Mobile::Enrollment::EmployeeEnrollment.new(assignments: assignments, grouped_bga_enrollments: grouped_bga_enrollments).populate_enrollments
      expect(enrollments).to be_a_kind_of Array
      expect(enrollments.size).to eq 2

      active = enrollments[0]
      renewal = enrollments[1]
      expect(active).to include('health', 'dental', :start_on)
      expect(renewal).to include('health', 'dental', :start_on)

      active_health, renewal_health = active['health'], renewal['health']
      active_dental, renewal_dental = active['dental'], renewal['dental']
      expect(active_health).to include(:status, :employer_contribution, :employee_cost,
                                       :total_premium, :plan_name, :plan_type, :metal_level,
                                       :benefit_group_name)
      expect(renewal_health).to include(:status, :employer_contribution, :employee_cost,
                                        :total_premium, :plan_name, :plan_type, :metal_level,
                                        :benefit_group_name)
      expect(active_dental).to include(:status)
      expect(renewal_dental).to include(:status)
      expect(active_health[:status]).to eq 'Enrolled'
      expect(renewal_health[:status]).to eq 'Enrolled'
      expect(active_dental[:status]).to eq 'Not Enrolled'
      expect(renewal_dental[:status]).to eq 'Not Enrolled'
    end

    it 'should initialize enrollments' do
      enrollment = Api::V1::Mobile::Enrollment::EmployeeEnrollment.new
      enrollments = enrollment.send(:__initialize_enrollment, [hbx_enrollment], 'health')
      expect(enrollments).to be_a_kind_of Hash
      expect(enrollments).to include(:status, :employer_contribution, :employee_cost, :total_premium, :plan_name,
                                     :plan_type, :metal_level, :benefit_group_name)
      enrollments = enrollment.send(:__initialize_enrollment, [hbx_enrollment], 'dental')
      expect(enrollments).to be_a_kind_of Hash
      expect(enrollments).to include(:status)
    end

    it 'should return the status label for enrollment status' do
      enrollment = Api::V1::Mobile::Enrollment::BaseEnrollment.new
      expect(enrollment.send(:__status_label_for, 'coverage_terminated')).to eq 'Terminated'
      expect(enrollment.send(:__status_label_for, 'inactive')).to eq 'Waived'
      expect(enrollment.send(:__status_label_for, 'auto_renewing')).to eq 'Enrolled'
      expect(enrollment.send(:__status_label_for, 'coverage_selected')).to eq 'Enrolled'
    end

  end

end