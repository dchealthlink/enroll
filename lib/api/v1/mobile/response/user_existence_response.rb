module Api
  module V1
    module Mobile::Response
      module UserExistenceResponse

        def ue_response person, employer_profiles, staff
          Jbuilder.encode do |json|
            _add_primary_applicant json, person
            _add_employers employer_profiles, json, staff
          end
        end

        def ue_error_response error_message
          Jbuilder.encode do |json|
            json.ridp_verified true
            json.error error_message
          end
        end

        #
        # Private
        #
        private

        def _add_primary_applicant json, person
          json.primary_applicant do
            json.id person.id
            json.user_id person.user_id
            json.first_name person.first_name
            json.last_name person.last_name
          end
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