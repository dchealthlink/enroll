module Api
  module V1
    module Mobile::Enrollment
      class EmployeeEnrollment < BaseEnrollment
        Util = Api::V1::Mobile::Util
        attr_accessor :grouped_bga_enrollments

        def initialize args={}
          super args
          @assignments = _unique_assignments if @benefit_group_assignments
        end

        def populate_enrollments insured_employee=nil
          @assignments.map do |assignment|
            result = _enrollment_hash insured_employee, assignment
            __health_and_dental! result, _hbx_enrollment(assignment)
            result
          end
        end

        #
        # Protected
        #
        protected

        def __specific_enrollment_fields enrollment
          {
              employer_contribution: enrollment.total_employer_contribution,
              employee_cost: enrollment.total_employee_cost,
          }
        end

        #
        # Private
        #
        private

        def _unique_assignments
          _current_or_upcoming_assignments { |bga| Util::BenefitGroupAssignmentsUtil.new(assignments: bga).unique_by_year }
        end

        def _current_or_upcoming_assignments
          yield @benefit_group_assignments.select { |a| Util::PlanYearUtil.new(plan_year: a.plan_year).is_current_or_upcoming? }
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