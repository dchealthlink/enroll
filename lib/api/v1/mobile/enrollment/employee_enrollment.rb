module Api
  module V1
    module Mobile::Enrollment
      class EmployeeEnrollment < BaseEnrollment
        Util = Api::V1::Mobile::Util
        attr_accessor :grouped_bga_enrollments

        def initialize args={}
          begin
            unique_assignments = ->() {
                Util::BenefitGroupAssignmentsUtil.new(assignments: @benefit_group_assignments).unique_by_year
            }
          end

          super args
          @assignments = unique_assignments.call if @benefit_group_assignments
        end

        def populate_enrollments dependent_count, insured_employee=nil, apply_ivl_rules=false
          begin
            current_or_upcoming_assignments = ->() {
              apply_ivl_rules ? @assignments : @assignments.select {|a| __is_current_or_upcoming? a.plan_year.start_on}
            }

            hbx_enrollments = ->(assignment) {
              enrollments = @grouped_bga_enrollments[assignment.id.to_s] if @grouped_bga_enrollments && !@grouped_bga_enrollments.empty?
              enrollments ? enrollments : assignment.hbx_enrollments
            }

            add_base_fields = ->(insured_employee, assignment, response) {
              response[:employer_profile_id] = insured_employee.employer_profile_id if insured_employee
              __add_default_fields! assignment.plan_year.start_on, assignment.plan_year.end_on, response
            }

            add_enrollments = ->() {
              current_or_upcoming_assignments.call.map {|assignment|
                response = {}
                add_base_fields[insured_employee, assignment, response]
                BaseEnrollment.excluding_invisible(hbx_enrollments[assignment]).map {|e|
                  __health_and_dental! response, e, dependent_count, apply_ivl_rules unless __has_enrolled? response, e
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

        def __specific_enrollment_fields enrollment, apply_ivl_rules=false
          begin
            add_contributions = ->(enrollment_attributes) {
              if apply_ivl_rules
                enrollment_attributes.merge(
                  total_premium_without_employer_contribution: enrollment.total_premium,
                  total_premium: enrollment.total_employee_cost
                )
              else
                enrollment_attributes.merge(
                  total_premium: enrollment.total_premium,
                  employee_cost: enrollment.total_employee_cost
                )
              end
            }
          end #lambda

          enrollment_attributes = {
            benefit_group_name: enrollment.try(:benefit_group).try(:title),
            employer_contribution: enrollment.total_employer_contribution
          }
          add_contributions[enrollment_attributes]
        end

      end
    end
  end
end