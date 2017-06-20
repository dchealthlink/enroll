module Api
  module V1
    module Mobile::Renderer
      module UserExistenceRenderer

        #
        # This request is honored only if the user making the request is the predefined HAVEN user driven by the
        # environment variable.
        #
        def render_details request, controller
          begin
            # Returns the SSN from the request body.
            person_request = ->() {BaseRenderer::payload_body(request)[:person]}
          end

          if controller.current_user.oim_id == ENV['HAVEN_USER_OIM_ID']
            controller.render json: Mobile::UserExistence.new(person_request: person_request.call).check_user_existence
          else
            BaseRenderer::report_error 'You are not authorized to make this request', controller, 401
          end
        end
      end

      UserExistenceRenderer.module_eval do
        module_function :render_details
      end
    end
  end
end