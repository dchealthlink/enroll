module Api
  module V1
    module Mobile::Ridp
      class RidpVerification < Api::V1::Mobile::Base

        #
        # Returns the Identity Verification questions (to the initial client request).
        #
        def build_question_response
          begin
            create_request_payload = ->() {_ridp_request_instance.create_question_request.to_xml}
            response = ->() {_verification_service_instance.initiate_session create_request_payload.call}
          end

          response.call
        end

        #
        # Returns the Identity Verification (Final) Response.
        #
        def build_answer_response
          begin
            create_request_payload = ->() {_ridp_request_instance.create_answer_request.to_xml}
            check_user_existence = ->(body) {Mobile::UserExistence.new(person_request: body[:person]).check_user_existence}

            response = ->() {
              @response ||= _verification_service_instance.respond_to_questions create_request_payload.call
            }

            error_response = ->() {JSON.parse(response.call.to_json).merge ridp_verified: false}
          end

          response.call.successful? ? check_user_existence[_ridp_request_instance.body] : error_response.call
        end

        #
        # Private
        #
        private

        def _ridp_request_instance
          @ridp_request ||= RidpRequest.new body: @body
        end

        def _verification_service_instance
          ::IdentityVerification::InteractiveVerificationService.new
        end

      end
    end
  end
end
