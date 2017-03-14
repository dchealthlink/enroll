module Api
  module V1
    module Mobile::Renderer
      module EmployerRenderer
        include BaseRenderer
        NO_EMPLOYER_DETAILS_FOUND = 'no employer details found'

        def render_employer_details details
          render json: details
        end

        def report_employer_error
          report_error NO_EMPLOYER_DETAILS_FOUND
        end

      end
    end
  end
end