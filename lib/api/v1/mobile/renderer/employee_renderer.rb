module Api
  module V1
    module Mobile::Renderer
      module EmployeeRenderer
        include MyBaseRenderer
        NO_EMPLOYEE_ROSTER_FOUND = 'no employee roster found'

        #
        # Private
        #
        private

        class << self

          def _can_view? security
            security.can_view_employee_roster?
          end

          def _render_response can_view, employer_profile, params, controller
            begin
              render_response = ->(employees) {
                begin
                  roster_employees = ->(employees) {
                    Api::V1::Mobile::Util::EmployeeUtil.new(employees: employees.limit(500).to_a,
                                                            employer_profile: employer_profile).roster_employees
                  }
                end

                controller.render json: {employer_name: employer_profile.legal_name,
                                         total_num_employees: employees.size, roster: roster_employees[employees]}
              }

              render_error = ->() {
                BaseRenderer::report_error NO_EMPLOYEE_ROSTER_FOUND, controller
              }
            end

            if can_view
              employees = Mobile::Util::EmployeeUtil.new(employer_profile: employer_profile,
                                                         employee_name: params[:employee_name],
                                                         status: params[:status]).employees_sorted_by
              employees ? render_response[employees] : render_error.call
            else
              render_error.call
            end
          end

        end
      end

      EmployeeRenderer.module_eval do
        module_function :render_details
        module_function :render_my_details
      end
    end
  end
end