module Api
  module V1
    module Mobile::Enrollment
      class EmployeeEnrollment < BaseEnrollment
        Util = Api::V1::Mobile::Util
        attr_accessor :grouped_bga_enrollments

        def initialize args={}
          super args
          @assignments = _current_or_upcoming_assignments if @benefit_group_assignments
        end

        def populate_enrollments insured_employee=nil
          @assignments.map do |assignment|
            result = _enrollment_hash insured_employee, assignment
            __health_and_dental! result, _hbx_enrollment(assignment)
            result
          end
        end

        #
        # Private
        #
        private

        def _enrollment_details coverage_kind, enrollment
          {
              hbx_enrollment_id: enrollment.id,
              status: __status_label_for(enrollment.aasm_state),
              employer_contribution: enrollment.total_employer_contribution,
              employee_cost: enrollment.total_employee_cost,
              total_premium: enrollment.total_premium,
              plan_name: enrollment.plan.try(:name),
              plan_type: enrollment.plan.try(:plan_type),
              metal_level: enrollment.plan.try(coverage_kind == :health ? :metal_level : :dental_level),
              benefit_group_name: enrollment.try(:benefit_group).try(:title)
          }
        end

        def _current_or_upcoming_assignments
          @benefit_group_assignments.select { |a| Util::PlanYearUtil.new(plan_year: a.plan_year).is_current_or_upcoming? }
        end

        def _enrollment_hash insured_employee, assignment
          enrollment = {}
          enrollment.merge! employer_profile_id: insured_employee.employer_profile_id if insured_employee
          enrollment.merge! start_on: assignment.plan_year.start_on
          enrollment
        end

        def _hbx_enrollment assignment
          hbx_enrollments = @grouped_bga_enrollments[assignment.id.to_s] if @grouped_bga_enrollments && !@grouped_bga_enrollments.empty?
          hbx_enrollments ? hbx_enrollments : assignment.hbx_enrollments
        end

      end
    end
  end
end