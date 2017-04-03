module Api
  module V1
    module Mobile::Renderer
      module IdentityVerificationRenderer
        include BaseRenderer
        IDENTITY_VERIFICATION_QUESTIONS_ERROR = 'identity verification questions were not received'

        def render_details params, controller
          begin
            render_response = ->() {
              controller.render json: Mobile::Ridp::IdentityVerification.new(params: params).build_response
            }
          end

          render_response.call
        end
      end

      IdentityVerificationRenderer.module_eval do
        module_function :render_details
      end
    end
  end
end