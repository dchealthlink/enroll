module Api
  module V1
    module Mobile::Renderer
      module BaseRenderer

        def report_error message, controller, status=:not_found
          controller.render json: {error: message}, status: status
        end

      end

      BaseRenderer.module_eval do
        module_function :report_error
      end
    end
  end
end