module Api
  module V1
    module Mobile::Renderer
      module PlanRenderer

        def render_details params, controller
          plan = _plan_instance params
          controller.render json: plan.all_available_plans
        end

        #
        # Private
        #
        private

        def self._plan_instance params
          Mobile::Plan.new coverage_kind: params[:coverage_kind], active_year: params[:active_year],
                           ages: params[:ages], csr_kind: params[:csr_kind],
                           elected_aptc_amount: params[:elected_aptc_amount]
        end

      end

      PlanRenderer.module_eval do
        module_function :render_details
      end
    end
  end
end