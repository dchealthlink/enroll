#
# @see https://paper.dropbox.com/doc/10341-RIDP-verification-error-handling-API-yCXbFrR6V9FTnmknVjKTn RIDP Error Handling
#
module Api
  module V1
    module Mobile::Ridp
      class RidpVerification < Api::V1::Mobile::Base
        include Api::V1::Mobile::Response::UserExistenceResponse

        @@status = 'success'

        def self.status
          @@status
        end
        #
        # Returns the Identity Verification questions to the initial client request.
        #
        def build_question_response
          begin
            # Creates the request payload to be sent to Experian.
            create_request_payload = ->() {
              xml_payload = _ridp_request_instance.create_question_request
              @session[:pii_data] = xml_payload[:pii_data]
              xml_payload[:xml].to_xml
            }
          end #lambda

          _ridp_request_instance.valid_request?.tap {|error_message|
            raise _error_response_message(ridp_invalid_client_request(error_message), 422) if error_message.present?
          }
          Rails.logger.info "<RIDP Question Request>: #{create_request_payload.call}"

          response = _verification_service_instance.initiate_session create_request_payload.call
          raise _error_response_message(ridp_initiate_session_unreachable_error, 503) unless response
          raise _error_response_message(ridp_initiate_session_unknown_error, 401) if response.session.nil? || !_response_code_matches(response.session.response_code, 'MORE_INFORMATION_REQUIRED')
          response
        end

        #
        # Returns the Identity Verification Response to answers submitted.
        #
        def build_answer_response
          begin
            # Creates the request payload to be sent to Experian.
            create_request_payload = ->() {_ridp_request_instance.create_answer_request.to_xml}
          end #lambda

          @@status = @params[:status] if @params[:status]
          Rails.logger.info "<<RIDP Answer Request>>: #{create_request_payload.call}"
          response = _verification_service_instance.respond_to_questions create_request_payload.call
          raise _error_response_message(ridp_initiate_session_unreachable_error, 503) unless response
          raise _error_response_message(ridp_respond_questions_failure_error(response.transaction_id), 412) if response.failed?
          raise _error_response_message(ridp_respond_questions_invalid_error, 403) if !_response_code_matches(response.verification_result.response_code, 'SUCCESS')
          _check_user_existence
        end

        #
        # Returns the Identity Verification Response to the check override request.
        #
        def build_check_override_response
          begin
            # Creates the request payload to be sent to Experian.
            create_request_payload = ->() {_ridp_request_instance.create_check_override_request.to_xml}
          end #lambda

          raise _error_response_message(transaction_id_missing, 422) unless @body[:transaction_id]
          response = _verification_service_instance.check_override create_request_payload.call
          Rails.logger.info "<<RIDP Answer Request>>: #{create_request_payload.call}"
          rraise _error_response_message(ridp_initiate_session_unreachable_error, 503) unless response
          raise _error_response_message(ridp_respond_questions_failure_error(response.transaction_id), 412) if !_response_code_matches(response.response_code, 'SUCCESS')
          _check_user_existence
        end

        #
        # Private
        #
        private

        # Checks for the existence of the user.
        def _check_user_existence
          Mobile::Ridp::RidpUserExistence.new(pii_data: @session[:pii_data]).check_user_existence
        end

        # Returns TRUE if Experian could be reached but we received an error response.
        def _response_code_matches response_code, error_code
          response_code.match(/#{error_code}$/)
        end

        # Error message to be returned to the client.
        def _error_response_message payload, code
          Mobile::Error::RIDPException.new JSON.parse(payload), code
        end

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
