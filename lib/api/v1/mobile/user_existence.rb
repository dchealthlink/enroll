module Api
  module V1
    module Mobile
      class UserExistence < Api::V1::Mobile::Base
        include ActionView::Helpers::NumberHelper
        include Api::V1::Mobile::Response::UserExistenceResponse

        SSN_EMPTY = 'ssn is empty'
        TOKEN_EXPIRES_IN_SECONDS = 30

        #
        # Check if the user exists in Enroll (as a registered user who can login), or in the Roster (as a dependent
        # of another primary applicant).
        #
        # If the client sends a SSN, we use that to find the user. If there is no SSN, we rely on a combination of
        # First Name, Last Name and Date of Birth to look up the user.
        #
        def check_user_existence
          begin
            # Checks if the person exists in the roster.
            check_roster = ->(person) {
              begin
                # Returns the encrypted token containing the SSN, DOB, FirstName and LastName.
                encrypt_token = ->(token) {
                  begin
                    encrypt_token_with_date = ->(pem_file) {
                      Base64.encode64 OpenSSL::PKey::RSA.new(File.read(pem_file)).public_encrypt(token)
                    }
                  end

                  pem_file = "#{Rails.root}/#{ENV['MOBILE_PEM_FILE']}"
                  File.file?(pem_file) ? token_response(encrypt_token_with_date[pem_file]) : token_response('')
                } #encrypt_token

                # Returns a response if the person were to have been found in the roster.
                create_response = ->(person) {
                  begin
                    staff = ->(employer_profiles) {
                      Api::V1::Mobile::Util::StaffUtil.new(employer_profiles: employer_profiles).keyed_by_employer_id
                    }
                  end

                  primary_applicant = Family.find_all_by_person(person).first.primary_applicant.person
                  employer_profiles = primary_applicant.employee_roles.map(&:employer_profile)
                  ue_response primary_applicant, employer_profiles, staff[employer_profiles]
                } #create_response

                # Returns the contents of the token that varies depending on whether or not there is an SSN attached to it.
                token_contents = ->() {
                  begin
                    # Returns the token expiration date and time.
                    token_expiration = ->() {
                      expires_in = ENV['TOKEN_EXPIRES_IN_SECONDS'] ? ENV['TOKEN_EXPIRES_IN_SECONDS'].to_i : TOKEN_EXPIRES_IN_SECONDS
                      (Time.now+expires_in).strftime('%m-%d-%Y %H:%M:%S')
                    } #token_expiration
                  end #lambda

                  token_contents_response @pii_data[:first_name], @pii_data[:last_name], @pii_data[:birth_date], token_expiration.call, @pii_data[:ssn]
                } #token_contents
              end

              response = {}
              __merge_these response, encrypt_token[token_contents.call]
              person ? __merge_these(response, create_response[person]) : __merge_these(response, ue_found_response(false))
              response
            } #check_roster

            # Returns a person for the given DOB, First Name and Last Name.
            find_by_dob_and_names = ->() {
              pers = Person.match_by_id_info dob: @pii_data[:birth_date],
                                             last_name: @pii_data[:last_name],
                                             first_name: @pii_data[:first_name]
              pers.first if pers.present?
            }

            # Returns the user for the given person, and an empty array if none is found.
            user = ->(person) {person.user if person.present?}
          end #lambda

          raise 'Invalid Request' unless @pii_data

          # If there is NO person found for either the given SSN or a combination of DOB/FirstName/LastName, check the roster.
          person = @pii_data[:ssn].present? ? Person.find_by_ssn(@pii_data[:ssn]) : find_by_dob_and_names.call
          user[person].present? ? ue_found_response(true) : check_roster[person]
        end

        #
        # Private
        #
        private

        def _add_employer_phone employer_profile, staff
          if staff[employer_profile.id].present?
            number_to_phone(staff[employer_profile.id].first.phones.first.full_phone_number, area_code: true)
          end
        end

      end
    end
  end
end