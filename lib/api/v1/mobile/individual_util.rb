module Api
  module V1
    module Mobile
      class IndividualUtil < BaseUtil
        include InsuredPerson

        def build_individual_json
          merge_all_this basic_person(@person), employments, enrollments, dependents
        end

        #
        # Private
        #
        private

        def merge_all_this *details
          hash = {}
          details.map { |m| hash.merge! JSON.parse(m) }
          hash
        end

        def employments
          Jbuilder.encode do |json|
            json.employments(@person.employee_roles) do |employee_role|
              employee_role.census_employee.tap do |employee|
                json.employer_profile_id employee.employer_profile_id
                json.employer_name employee.employer_profile.legal_name
                json.hired_on employee.hired_on
                json.is_business_owner employee.is_business_owner
              end
            end
          end
        end

        def enrollments
          result = []
          Jbuilder.encode do |json|
            @person.employee_roles.map do |employee_role|
              employee_role.census_employee.tap do |employee|
                enrollment_util = EnrollmentUtil.new benefit_group_assignments: employee.benefit_group_assignments
                result << enrollment_util.employee_enrollments(employee)
              end
            end
            json.enrollments result.flatten
          end
        end

        def dependents
          Jbuilder.encode do |json|
            employee_role = @person.employee_roles.first
            employee_role.census_employee.tap do |employee|
              json.dependents include_dependents_to employee
            end if employee_role
          end
        end

      end
    end
  end
end