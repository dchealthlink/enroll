module Api
  module V1
    module Mobile::Renderer
      module UserExistenceRenderer

        #
        # This request is honored only if the user making the request is the predefined HAVEN user driven by the
        # environment variable.
        #
        def render_details params, controller
          if controller.current_user.email == ENV['HAVEN_USER']
            controller.render json: Mobile::UserExistence.new(ssn: params[:ssn]).check_user_existence
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