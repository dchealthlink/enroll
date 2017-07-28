module Api
  module V1
    module Mobile
      class UserExistence < Api::V1::Mobile::Base
        include ActionView::Helpers::NumberHelper
        include Api::V1::Mobile::Response::UserExistenceResponse

        #
        # Check if the user exists in Enroll (as a registered user who can login), or in the Roster (as a dependent
        # of another primary applicant).
        #
        def check_user_existence
          person = __find_person
          person ? primary_applicant_response(person): user_not_found_response
        end

        #
        # Protected
        #
        protected

        #
        # If the client sends a SSN, we use that to find the user. If there is no SSN, we rely on a combination of
        # First Name, Last Name and Date of Birth to look up the user.
        #
        def __find_person
          begin
            # Returns a person for the given DOB, First Name and Last Name.
            find_by_dob_and_names = ->() {
              pers = Person.match_by_id_info dob: @pii_data[:birth_date],
                                             last_name: @pii_data[:last_name],
                                             first_name: @pii_data[:first_name]
              pers.first if pers.present?
            }
          end #lambda

          raise 'Invalid Request' unless @pii_data

          # If there is NO person found for either the given SSN or a combination of DOB/FirstName/LastName, check the roster.
          @pii_data[:ssn].present? ? Person.find_by_ssn(@pii_data[:ssn]) : find_by_dob_and_names.call
        end

        #
        # Private
        #
        private

        def _add_employer_phone employer_profile, staff
          if staff[employer_profile.id].present?
            number_to_phone(staff[employer_profile.id].first.phones.first.try(:full_phone_number), area_code: true)
          end
        end

      end
    end
  end
end