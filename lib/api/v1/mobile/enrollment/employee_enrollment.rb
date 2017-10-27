module Api
  module V1
    module Mobile::Enrollment
      class EmployeeEnrollment < BaseEnrollment
        Util = Api::V1::Mobile::Util
        attr_accessor :grouped_bga_enrollments

        def initialize args={}
          begin
            current_or_upcoming_assignments = ->(&block) {
              block.call @benefit_group_assignments.select {|a| __is_current_or_upcoming? a.plan_year.start_on}
            }

            unique_assignments = ->() {
              current_or_upcoming_assignments.call {|bgas|
                Util::BenefitGroupAssignmentsUtil.new(assignments: bgas).unique_by_year
              }
            }
          end

          super args
          @assignments = unique_assignments.call if @benefit_group_assignments
        end

        def populate_enrollments insured_employee=nil
          begin
            hbx_enrollments = ->(assignment) {
              enrollments = @grouped_bga_enrollments[assignment.id.to_s] if @grouped_bga_enrollments && !@grouped_bga_enrollments.empty?
              enrollments ? enrollments : assignment.hbx_enrollments
            }

            add_base_fields = ->(insured_employee, assignment, response) {
              response[:employer_profile_id] = insured_employee.employer_profile_id if insured_employee
              __add_default_fields! assignment.plan_year.start_on, assignment.plan_year.end_on, response
            }

            add_enrollments = ->() {
              @assignments.map {|assignment|
                response = {}
                add_base_fields[insured_employee, assignment, response]
                hbx_enrollments[assignment].map {|e|
                  __health_and_dental! response, e unless __has_enrolled? response, e
                }
                response
              }
            }
          end

          add_enrollments.call
        end

        #
        # Protected
        #
        protected

        def __specific_enrollment_fields enrollment
          {
            total_premium: enrollment.total_premium,
            benefit_group_name: enrollment.try(:benefit_group).try(:title),
            employer_contribution: enrollment.total_employer_contribution,
            employee_cost: enrollment.total_employee_cost,
          }
        end

      end
    end
  end
end