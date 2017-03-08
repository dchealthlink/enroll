module Api
  module V1
    module Mobile::Insured
      module InsuredEmployee
        Util = Api::V1::Mobile::Util

        def ie_employments person
          Jbuilder.encode do |json|
            json.employments(person.employee_roles) do |employee_role|
              employee_role.census_employee.tap do |employee|
                json.employer_profile_id employee.employer_profile_id
                json.employer_name employee.employer_profile.legal_name
                json.hired_on employee.hired_on
                json.is_business_owner employee.is_business_owner
              end
            end
          end
        end

        def ie_enrollments person
          result = []
          Jbuilder.encode do |json|
            person.employee_roles.each do |employee_role|
              employee_role.census_employee.tap do |employee|
                enrollment_util = Util::EnrollmentUtil.new benefit_group_assignments: employee.benefit_group_assignments
                result << enrollment_util.employee_enrollments(employee)
              end
            end
            json.enrollments result.flatten
          end
        end

      end
    end
  end
end