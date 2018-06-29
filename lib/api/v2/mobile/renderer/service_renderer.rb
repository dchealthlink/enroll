module Api
  module V2
    module Mobile::Renderer
      module ServiceRenderer
        include BaseRenderer
        PARAMETERS_MISSING = 'Required parameters: hios_id, coverage_kind, active_year'

        def render_details params, controller
          begin
            render_response = ->(hios_id, active_year, coverage_kind) {
              controller.render json: Mobile::Enrollment::BaseEnrollment.new.services_rates(
                hios_id, active_year, coverage_kind)
            }

            render_error = ->() {
              BaseRenderer::report_error({error: PARAMETERS_MISSING}, controller, :unprocessable_entity)
            }
          end

          hios_id, active_year, coverage_kind = params.values_at :hios_id, :active_year, :coverage_kind
          if hios_id && active_year && coverage_kind
            render_response[hios_id, active_year, coverage_kind]
          else
            render_error.call
          end
        end
      end

      ServiceRenderer.module_eval do
        module_function :render_details
      end
    end
  end
end