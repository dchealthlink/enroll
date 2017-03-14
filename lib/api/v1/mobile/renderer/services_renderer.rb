module Api
  module V1
    module Mobile::Renderer
      module ServicesRenderer

        def render_details hios_id, active_year, coverage_kind, controller
          controller.render json: Mobile::Enrollment::BaseEnrollment.new.services_rates(hios_id, active_year, coverage_kind)
        end

      end

      ServicesRenderer.module_eval do
        module_function :render_details
      end
    end
  end
end