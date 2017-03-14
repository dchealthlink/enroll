module Api
  module V1
    module Mobile::Renderer
      module ServicesRenderer

        def render_services_rates_details hios_id, active_year, coverage_kind
          render json: Mobile::Enrollment::BaseEnrollment.new.services_rates(hios_id, active_year, coverage_kind)
        end

      end
    end
  end
end