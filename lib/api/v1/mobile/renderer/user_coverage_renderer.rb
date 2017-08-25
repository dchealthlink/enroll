module Api
  module V1
    module Mobile::Renderer
      module UserCoverageRenderer

        #
        # This request is honored only if the request originates in the Mobile Integration Server.
        #
        def render_details request, params, controller
          user_coverage = Mobile::UserCoverage.new(payload: BaseRenderer::payload_body(request))
          if user_coverage.token_valid?
            begin
              controller.render json: user_coverage.check_user_coverage
            rescue StandardError => e
              BaseRenderer::report_error({error: e.message}, controller, 404)
            end
          else
            BaseRenderer::report_error({error: 'You are not authorized to make this request'}, controller, 401)
          end
        end
      end

      UserCoverageRenderer.module_eval do
        module_function :render_details
      end
    end
  end
end