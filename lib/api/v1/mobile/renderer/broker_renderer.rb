module Api
  module V1
    module Mobile::Renderer
      module BrokerRenderer
        NO_BROKER_AGENCY_PROFILE_FOUND = 'no broker agency profile or broker role found'

        def render_details response, controller
          controller.render json: response
        end

        def report_error status, controller
          BaseRenderer::report_error NO_BROKER_AGENCY_PROFILE_FOUND, controller, status
        end
      end

      BrokerRenderer.module_eval do
        module_function :render_details
        module_function :report_error
      end
    end
  end
end