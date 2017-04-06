module Api
  module V1
    module Mobile::Ridp
      class RidpVerification < Api::V1::Mobile::Base

        def build_question_response
          begin
            create_request_payload = ->() { _ridp_request_instance.create_question_request.to_xml }
            response = ->() { _verification_service_instance.initiate_session create_request_payload.call }
          end

          response.call
        end

        def build_answer_response
          begin
            create_request_payload = ->() { _ridp_request_instance.create_answer_request.to_xml }
            response = ->() { _verification_service_instance.respond_to_questions create_request_payload.call }
          end

          response.call
        end

        #
        # Private
        #
        private

        def _ridp_request_instance
          RidpRequest.new body: JSON.parse(@body)
        end

        def _verification_service_instance
          ::IdentityVerification::InteractiveVerificationService.new
        end

      end
    end
  end
end
