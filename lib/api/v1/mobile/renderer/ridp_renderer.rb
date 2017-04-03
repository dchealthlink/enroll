module Api
  module V1
    module Mobile::Renderer
      module RidpRenderer
        include BaseRenderer
        IDENTITY_VERIFICATION_QUESTIONS_ERROR = 'identity verification questions were not received'

        def render_details request, controller
          begin
            render_response = ->() {
              controller.render json: Mobile::Ridp::RidpVerification.new(request: request).build_response
            }
          end

          render_response.call
        end
      end

      RidpRenderer.module_eval do
        module_function :render_details
      end
    end
  end
end