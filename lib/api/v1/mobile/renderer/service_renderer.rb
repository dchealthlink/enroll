module Api
  module V1
    module Mobile::Renderer
      module ServiceRenderer
        PARAMETERS_MISSING = 'Required parameters: hios_id, coverage_kind, active_year'

        def render_details hios_id, active_year, coverage_kind, controller
          controller.render json: Mobile::Enrollment::BaseEnrollment.new.services_rates(hios_id, active_year, coverage_kind)
        end

        def report_error controller
          BaseRenderer::report_error PARAMETERS_MISSING, controller, :unprocessable_entity
        end
      end

      ServiceRenderer.module_eval do
        module_function :render_details
        module_function :report_error
      end
    end
  end
end