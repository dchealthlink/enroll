module Api
  module V1
    module Mobile::Renderer
      module IndividualRenderer
        include BaseRenderer
        NO_INDIVIDUAL_DETAILS_FOUND = 'no individual details found'

        def render_insured_details person
          render json: Api::V1::Mobile::Util::InsuredUtil.new(person: person).build_insured_json
        end

        def report_insured_error
          report_error NO_INDIVIDUAL_DETAILS_FOUND
        end

      end
    end
  end
end