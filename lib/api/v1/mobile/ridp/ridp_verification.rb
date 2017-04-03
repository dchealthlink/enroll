module Api
  module V1
    module Mobile::Ridp
      class RidpVerification < Api::V1::Mobile::Base

        def build_response
          begin
            create_request_payload = ->() {
              ridp_request = RidpRequest.new body: JSON.parse(@request.body.read)
              payload = ridp_request.create_request
              payload.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::AS_XML).strip
            }

            questions_response = ->(payload) {
              Rails.logger.error "payload: #{payload}"
              service = ::IdentityVerification::InteractiveVerificationService.new
              service.initiate_session payload
            }
          end

          response questions_response[create_request_payload.call]
          Rails.logger.error "response: #{response}"
          response
        end

      end
    end
  end
end
