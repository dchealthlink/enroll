module Api
  module V1
    module Mobile::Renderer
      module InsuredRenderer
        include BaseRenderer
        NO_INDIVIDUAL_DETAILS_FOUND = 'no individual details found'

        def render_details current_user, params, controller
          security = Mobile::Util::SecurityUtil.new(user: current_user, params: params)
          _render_response security.person, controller, security.can_view_insured?
        end

        def render_my_details current_user, controller
          _render_response current_user.person, controller
        end

        #
        # Private
        #
        private

        class << self

          def _render_response person, controller, can_view=true
            begin
              render_response = ->() {
                controller.render json: Api::V1::Mobile::Util::InsuredUtil.new(person: person).build_response
              }

              render_error = ->() {
                BaseRenderer::report_error({error: NO_INDIVIDUAL_DETAILS_FOUND}, controller)
              }
            end

            can_view ? render_response.call : render_error.call
          end

        end
      end

      InsuredRenderer.module_eval do
        module_function :render_details
        module_function :render_my_details
      end
    end
  end
end