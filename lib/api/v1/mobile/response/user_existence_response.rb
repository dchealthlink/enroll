module Api
  module V1
    module Mobile::Response
      module UserExistenceResponse

        def ue_response person, employer_profiles, staff
          Jbuilder.encode do |json|
            _ridp_verified json, true
            _add_primary_applicant json, person
            _add_employers employer_profiles, json, staff
          end
        end

        def transaction_id_missing
          _error_response 'Transaction id needs to be passed'
        end

        def user_not_found_response
          _error_response 'User not found'
        end

        def ue_found_response flag
          Jbuilder.encode do |json|
            _ridp_verified json, true
            json.user_found_in_enroll flag
          end
        end

        def ridp_initiate_session_unreachable_error
          _ridp_initiate_session_error_response 'unreachable',
                                                'We are sorry. The third-party service used to confirm your identity is currently '\
                                                'unavailable. Please try again later. If you continue to receive this message after '\
                                                'trying several times, please call DC Health Link customer service for assistance at 1-855-532-5464.'
        end

        def ridp_initiate_session_unknown_error
          _ridp_initiate_session_error_response 'cannot formulate questions for this consumer',
                                                'To keep your data secure, we are required to verify your identity electronically '\
                                                'using the credit reporting agency Experian. Unfortunately, Experian was unable to '\
                                                'confirm your identity based on the information you provided. You will need to '\
                                                'complete your application at the DC Health Benefit Exchange Authority office at '\
                                                '1225 I St NW. Please call (202) 715-7576 to set up an appointment.'
        end

        def ridp_respond_questions_invalid_error
          _ridp_initiate_session_error_response 'identity could not be verified',
                                                'Experian was unable to confirm your identity based on the information '\
                                                'you provided. You will need to complete your application at the '\
                                                'DC Health Benefit Exchange Authority office at 1225 I St NW. '\
                                                'Please call (202) 715-7576 to set up an appointment.'
        end

        def ridp_respond_questions_failure_error transaction_id
          _ridp_initiate_session_error_response 'identity could not be verified',
                                                'You have not passed identity validation. To proceed please contact '\
                                                "Experian at 1-866-578-5409, and provide them with reference number #{transaction_id}.",
                                                transaction_id
        end

        def token_contents_response first_name, last_name, dob, expires_at, ssn
          Jbuilder.encode do |json|
            json.ssn ssn
            json.first_name first_name
            json.last_name last_name
            json.dob dob
            json.expires_at expires_at
          end
        end

        def token_response token
          Jbuilder.encode do |json|
            json.token token
          end
        end

        def primary_applicant_response person
          Jbuilder.encode do |json|
            _add_person json, person
            json.ssn person.ssn
            json.gender person.gender
            json.dob person.dob
            json.addresses person.addresses
            json.emails person.emails
          end
        end

        #
        # Private
        #
        private

        def _error_response error_message
          Jbuilder.encode do |json|
            json.message error_message
          end
        end

        def _ridp_initiate_session_error_response code, text, transaction_id=nil
          Jbuilder.encode do |json|
            json.verification_result do
              json.response_code code
              json.response_text text
              json.transaction_id transaction_id if transaction_id
            end
            json.session nil
            json.ridp_verified false
          end
        end

        def _ridp_verified json, flag
          json.ridp_verified flag
        end

        def _add_primary_applicant json, person
          json.primary_applicant do
            _add_person json, person
          end
        end

        def _add_person json, person
          json.id person.id
          json.user_id person.user_id
          json.first_name person.first_name
          json.last_name person.last_name
        end

        def _add_employers employer_profiles, json, staff
          json.employers do
            json.array! employer_profiles do |employer_profile|
              _add_employer_profile employer_profile, json, staff
              _add_broker_profile employer_profile, json
            end
          end
        end

        def _add_broker_profile employer_profile, json
          json.broker do
            employer_profile.broker_agency_profile.tap {|bap|
              if bap
                json.id bap.id
                json.organization_legal_name bap.legal_name
                json.legal_name employer_profile.try(:active_broker).try(:full_name)
                json.phone bap.phone
              end
            }
          end
        end

        def _add_employer_profile employer_profile, json, staff
          json.employer do
            json.id employer_profile.id
            json.legal_name employer_profile.legal_name
            json.phone _add_employer_phone employer_profile, staff
          end
        end

      end
    end
  end
end