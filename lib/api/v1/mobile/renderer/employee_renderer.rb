module Api
  module V1
    module Mobile::Renderer
      module EmployeeRenderer
        include BaseRenderer
        NO_EMPLOYEE_ROSTER_FOUND = 'no employee roster found'
        
        def render_employee_roster employer_profile, employees
          render json: {
              employer_name: employer_profile.legal_name,
              total_num_employees: employees.size,
              roster: Api::V1::Mobile::Util::EmployeeUtil.new(employees: employees.limit(500).to_a, employer_profile: employer_profile).roster_employees}
        end

        def report_employee_error
          report_error NO_EMPLOYEE_ROSTER_FOUND
        end
        
      end
    end
  end
end