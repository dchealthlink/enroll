module Api
  module V1
    module Mobile::Ridp
      class RidpVerification < Api::V1::Mobile::Base

        def build_response
          begin
            create_request_payload = ->() {
              ridp_request = RidpRequest.new body: JSON.parse(@body)
              ridp_request.create_request.to_xml
            }

            questions_response = ->(payload) {
              service = ::IdentityVerification::InteractiveVerificationService.new
              service.initiate_session payload
            }
          end

          questions_response[create_request_payload.call]
        end

      end
    end
  end
end
