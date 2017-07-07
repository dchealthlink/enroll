module Api
  module V1
    module Mobile::Ridp
      class RidpUserExistence < Mobile::UserExistence
        TOKEN_EXPIRES_IN_SECONDS = 30
        PEM_FILE = 'pem/symmetric.pem'

        #
        # Check if the user exists in Enroll (as a registered user who can login), or in the Roster (as a dependent
        # of another primary applicant).
        #
        def check_user_existence
          # Returns the user for the given person, and an empty array if none is found.
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

                  pem_file = "#{Rails.root}/".concat(ENV['MOBILE_PEM_FILE'] || PEM_FILE)
                  raise 'pem file is missing' unless File.file? pem_file
                  token_response encrypt_token_with_date[pem_file]
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

            user = ->(person) {person.user if person.present?}
          end #lambda

          person = __find_person
          user[person].present? ? ue_found_response(true) : check_roster[person].to_json
        end

      end
    end
  end
end