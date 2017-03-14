module Api
  module V1
    module Mobile::Renderer
      module EmployeeRenderer
        include BaseRenderer
        NO_EMPLOYEE_ROSTER_FOUND = 'no employee roster found'

        def render_details employer_profile, employees, controller
          controller.render json: {
              employer_name: employer_profile.legal_name,
              total_num_employees: employees.size,
              roster: Api::V1::Mobile::Util::EmployeeUtil.new(employees: employees.limit(500).to_a, employer_profile: employer_profile).roster_employees}
        end

        def report_error controller
          BaseRenderer::report_error NO_EMPLOYEE_ROSTER_FOUND, controller
        end
      end

      EmployeeRenderer.module_eval do
        module_function :render_details
        module_function :report_error
      end
    end
  end
end