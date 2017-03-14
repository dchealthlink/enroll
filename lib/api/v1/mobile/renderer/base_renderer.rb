module Api
  module V1
    module Mobile::Renderer
      module BaseRenderer

        def report_error message
          render json: {error: message}, status: :not_found
        end

      end
    end
  end
end