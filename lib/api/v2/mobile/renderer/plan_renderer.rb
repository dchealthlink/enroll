module Api
  module V2
    module Mobile::Renderer
      module PlanRenderer

        def render_details params, controller
          begin
            plan_instance = ->() {
              Mobile::Plan.new coverage_kind: params[:coverage_kind], active_year: params[:active_year],
                               ages: params[:ages], csr_kind: params[:csr_kind],
                               elected_aptc_amount: params[:elected_aptc_amount]
            }
          end

          controller.render json: plan_instance.call.all_available_plans
        end
      end

      PlanRenderer.module_eval do
        module_function :render_details
      end
    end
  end
end