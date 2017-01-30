module Api
  module V1
    module Mobile
      class IndividualUtil < BaseUtil

        def build_individual_json
          @employee_util = EmployeeUtil.new
          individual = @employee_util.basic_individual @person
          JSON.parse(individual).merge JSON.parse(enrollments).merge JSON.parse(dependents)
        end

        #
        # Private
        #
        private

        def enrollments
          Jbuilder.encode do |json|
            json.employments(@person.employee_roles) do |employee_role|
              employee_role.census_employee.tap do |employee|
                json.employer_profile_id employee.employer_profile_id
                json.employer_name employee.employer_profile.legal_name
                json.hired_on employee.hired_on
                json.is_business_owner employee.is_business_owner

                enrollment_util = EnrollmentUtil.new benefit_group_assignments: employee.benefit_group_assignments
                json.enrollments enrollment_util.employee_enrollments
              end
            end
          end
        end

        def dependents
          Jbuilder.encode do |json|
            employee_role = @person.employee_roles.first
            employee_role.census_employee.tap do |employee|
              json.dependents @employee_util.add_dependents employee
            end if employee_role
          end
        end

      end
    end
  end
end