module Api
  module V1
    module Mobile::Renderer
      module IndividualRenderer
        include BaseRenderer
        NO_INDIVIDUAL_DETAILS_FOUND = 'no individual details found'

        def render_details person, controller
          controller.render json: Api::V1::Mobile::Util::InsuredUtil.new(person: person).build_insured_json
        end

        def report_error controller
          BaseRenderer::report_error NO_INDIVIDUAL_DETAILS_FOUND, controller
        end
      end

      IndividualRenderer.module_eval do
        module_function :render_details
        module_function :report_error
      end
    end
  end
end