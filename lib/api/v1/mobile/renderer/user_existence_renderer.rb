module Api
  module V1
    module Mobile::Renderer
      module UserExistenceRenderer
        include BaseRenderer
        extend Api::V1::Mobile::Util::UrlUtil

        def render_details request, controller
          begin
            render_response = ->() {
              controller.render json: Mobile::UserExistence.new(body: request.body.read).check_user_existence
            }
          end

          BaseRenderer::execute render_response, controller
        end
      end

      UserExistenceRenderer.module_eval do
        module_function :render_details
      end
    end
  end
end