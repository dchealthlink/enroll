module Api
  module V1
    module Mobile::Renderer
      module EmployerRenderer
        include BaseRenderer
        NO_EMPLOYER_DETAILS_FOUND = 'no employer details found'

        def render_details details, controller
          controller.render json: details
        end

        def report_error controller
          BaseRenderer::report_error NO_EMPLOYER_DETAILS_FOUND, controller
        end
      end

      EmployerRenderer.module_eval do
        module_function :render_details
        module_function :report_error
      end
    end
  end
end