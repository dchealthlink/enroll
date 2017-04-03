module Api
  module V1
    module Mobile::Renderer
      module BrokerRenderer
        include BaseRenderer
        NO_BROKER_AGENCY_PROFILE_FOUND = 'no broker agency profile or broker role found'

        def render_details current_user, params, controller
          begin
            render_response = ->(authorized) {
              employer = Mobile::Util::EmployerUtil.new authorized: authorized, user: current_user
              controller.render json: employer.employers_and_broker_agency
            }

            render_error = ->(authorized) {
              BaseRenderer::report_error NO_BROKER_AGENCY_PROFILE_FOUND, controller, authorized[:status]
            }
          end

          authorized = Mobile::Util::SecurityUtil.new(user: current_user, params: params).authorize_employer_list
          authorized[:status] == 200 ? render_response[authorized] : render_error[authorized]
        end
      end

      BrokerRenderer.module_eval do
        module_function :render_details
      end
    end
  end
end