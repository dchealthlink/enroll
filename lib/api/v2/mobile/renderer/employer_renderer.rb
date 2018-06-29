module Api
  module V2
    module Mobile::Renderer
      module EmployerRenderer
        include EmployeeEmployerRenderer
        NO_EMPLOYER_DETAILS_FOUND = 'no employer details found'

        #
        # Private
        #
        private

        class << self

          def _can_view? security
            security.can_view_employer_details?
          end

          def _render_response can_view, employer_profile, params, controller
            begin
              render_response = ->() {
                employer = Mobile::Util::EmployerUtil.new employer_profile: employer_profile,
                                                          report_date: params[:report_date]
                controller.render json: employer.employer_details
              }

              render_error = ->() {
                BaseRenderer::report_error({error: NO_EMPLOYER_DETAILS_FOUND}, controller)
              }
            end

            can_view ? render_response.call : render_error.call
          end
        end

      end

      EmployerRenderer.module_eval do
        module_function :render_details
        module_function :render_my_details
      end
    end
  end
end