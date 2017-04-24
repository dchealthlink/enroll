module Api
  module V1
    module Mobile::Enrollment
      class EmployeeEnrollment < BaseEnrollment
        Util = Api::V1::Mobile::Util
        attr_accessor :grouped_bga_enrollments

        def initialize args={}
          begin
            current_or_upcoming_assignments = ->(&block) {
              block.call @benefit_group_assignments.select { |a|
                Util::PlanYearUtil.new(plan_year: a.plan_year).is_current_or_upcoming?
              }
            }

            unique_assignments = ->() {
              current_or_upcoming_assignments.call { |bgas|
                Util::BenefitGroupAssignmentsUtil.new(assignments: bgas).unique_by_year
              }
            }
          end

          super args
          @assignments = unique_assignments.call if @benefit_group_assignments
        end

        def populate_enrollments insured_employee=nil
          begin
            hbx_enrollment = ->(assignment) {
              hbx_enrollments = @grouped_bga_enrollments[assignment.id.to_s] if @grouped_bga_enrollments && !@grouped_bga_enrollments.empty?
              hbx_enrollments ? hbx_enrollments : assignment.hbx_enrollments
            }

            enrollment_hash = ->(insured_employee, assignment) {
              enrollment = {}
              enrollment[:employer_profile_id] = insured_employee.employer_profile_id if insured_employee
              enrollment[:start_on] = assignment.plan_year.start_on
              enrollment
            }
          end

          @assignments.map do |assignment|
            result = enrollment_hash[insured_employee, assignment]
            __health_and_dental! result, hbx_enrollment[assignment]
            result
          end
        end

        #
        # Protected
        #
        protected

        def __specific_enrollment_fields enrollment
          {
            benefit_group_name: enrollment.try(:benefit_group).try(:title),
            employer_contribution: enrollment.total_employer_contribution,
            employee_cost: enrollment.total_employee_cost,
          }
        end

      end
    end
  end
end