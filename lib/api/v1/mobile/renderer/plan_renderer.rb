module Api
  module V1
    module Mobile::Renderer
      module PlanRenderer

        def render_details params, controller
          controller.render json: Mobile::Plan.new.all_plans(params)
        end

      end

      PlanRenderer.module_eval do
        module_function :render_details
      end
    end
  end
end