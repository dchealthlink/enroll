module Api
  module V1
    module Mobile
      class UserExistence < Api::V1::Mobile::Base
        include ActionView::Helpers::NumberHelper
        include Api::V1::Mobile::Response::UserExistenceResponse

        SSN_EMPTY = 'ssn is empty'
        TOKEN_EXPIRES_IN_SECONDS = 30

        def check_user_existence
          begin
            staff = ->(employer_profiles) {
              Api::V1::Mobile::Util::StaffUtil.new(employer_profiles: employer_profiles).keyed_by_employer_id
            }

            create_response = ->(person) {
              primary_applicant = Family.find_all_by_person(person).first.try(:primary_applicant).person
              employer_profiles = primary_applicant.employee_roles.map(&:employer_profile)
              ue_response primary_applicant, employer_profiles, staff[employer_profiles]
            }

            encrypt_ssn_with_date = ->(pem_file) {
              Base64.encode64 OpenSSL::PKey::RSA.new(File.read(pem_file)).public_encrypt(
                token_contents_response(@ssn, (Time.now+TOKEN_EXPIRES_IN_SECONDS).strftime('%m-%d-%Y %H:%M:%S')))
            }

            encrypted_token = ->() {
              pem_file = "#{Rails.root}/#{ENV['MOBILE_PEM_FILE']}"
              File.file?(pem_file) ? token_response(encrypt_ssn_with_date[pem_file]) : token_reponse('')
            }

            check_roster = ->() {
              person = Person.where(encrypted_ssn: Person.encrypt_ssn(@ssn)).first
              if person
                create_response[person]
              else
                response = {}
                __merge_these response, ue_found_response(false), encrypted_token.call
                response
              end
            }
          end

          errors = Forms::ConsumerCandidate.new(ssn: @ssn).uniq_ssn
          if errors.present? # Either there is a user already with this SSN or the SSN is empty.
            errors == true ? ue_error_response(SSN_EMPTY) : ue_found_response(true)
          else
            check_roster.call # No corresponding user for this SSN, so check the roster.
          end
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