module Api
  module V1
    module Mobile
      class UserCoverage < Api::V1::Mobile::Base
        include Api::V1::Mobile::Response::UserExistenceResponse

        def initialize args
          super args
          @pii_data = @payload[:person]
        end

        #
        # Token is valid if the SSN or PII information (First Name, Last Name, Date of Birth) match and it hasn't expired.
        #
        def token_valid?
          begin
            # Decrypts the token using symmetric encryption & returns it.
            decrypted_token = ->(pem_file) {
              OpenSSL::PKey::RSA.new(File.read(pem_file)).private_decrypt Base64.decode64 @payload[:token]
            }

            # Verifies the validity of the token passed.
            is_valid = ->(token) {
              begin
                # Returns true if PII matches.
                pii_matches = ->() {
                  @payload[:person][:first_name] == token[:person][:first_name] &&
                      @payload[:person][:last_name] == token[:person][:last_name] &&
                      @payload[:person][:birth_date] == token[:person][:birth_date] &&
                      @payload[:person][:ssn] == token[:person][:ssn]
                }
              end #lambda

              expired = true
              matches = pii_matches.call
              Rails.logger.error 'contents of token do not match' unless matches
              if matches
                expired = Time.strptime(token[:expires_at], '%m-%d-%Y %H:%M:%S') <= Time.now
                Rails.logger.error 'token has expired' if expired
              end
              matches && !expired
            }
          end # lambda

          begin
            token = JSON.parse(decrypted_token[__pem_file_exists?]).with_indifferent_access
            is_valid[token]
          rescue StandardError => e
            Rails.logger.error "authorization failed since token is invalid: #{e.message}"
            false
          end
        end

        #
        # Check if the user exists in Enroll (as a registered user who can login) and if they do, return their
        # enrollments.
        #
        def check_user_coverage
          person = __find_person
          raise 'Person was not found' unless person
          {enrollments: Api::V1::Mobile::Util::InsuredUtil.new(person: person).build_response['enrollments']}
        end

      end
    end
  end
end