module Api
  module V2
    module Mobile::Insured
      class InsuredEmployee < InsuredPerson
        Mobile = Api::V2::Mobile

        def ins_employments
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

        def ins_enrollments dependent_count
          result = []
          @person.employee_roles.each do |employee_role|
            employee_role.census_employee.tap do |employee|
              enrollment = Mobile::Enrollment::EmployeeEnrollment.new benefit_group_assignments: employee.benefit_group_assignments
              result << enrollment.populate_enrollments(dependent_count, employee, true)
            end
          end
          result
        end

      end
    end
  end
end