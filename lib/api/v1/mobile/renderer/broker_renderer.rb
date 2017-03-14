module Api
  module V1
    module Mobile::Renderer
      module BrokerRenderer
        NO_BROKER_AGENCY_PROFILE_FOUND = 'no broker agency profile or broker role found'

        def render_broker response
          render json: response
        end

        def report_broker_error status='not_found'
          render json: {error: NO_BROKER_AGENCY_PROFILE_FOUND}, status: status
        end

      end
    end
  end
end