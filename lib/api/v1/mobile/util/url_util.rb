module Api
  module V1
    module Mobile::Util
      module UrlUtil
        BASE = '/api/v1/mobile'

        #
        # get :broker
        #
        def broker_path
          "#{BASE}/broker"
        end

        #
        # get 'broker_agency_profile_id/:broker_agency_profile_id', action: :broker
        #
        def broker_with_broker_agency_path broker_agency_profile_id
          "#{BASE}/broker_agency_profile_id/#{broker_agency_profile_id}"
        end

        #
        # get 'employers/:employer_profile_id/details', action: :employer_details
        #
        def employers_details_path employer_profile_id
          "#{BASE}/employers/#{employer_profile_id}/details"
        end

        #
        # get 'employers/:employer_profile_id/employees', action: :employee_roster
        #
        def employers_employees_path employer_profile_id
          "#{BASE}/employers/#{employer_profile_id}/employees"
        end

        #
        # get 'employer/details', action: :my_employer_details
        #
        def employer_details_path
          "#{BASE}/employer/details"
        end

        #
        # get 'employer/employees', action: :my_employee_roster
        #
        def employees_path
          "#{BASE}/employer/employees"
        end

        #
        # get :services_rates
        #
        def services_rates_path hios_id, active_year, coverage_kind
          "#{BASE}/services_rates?hios_id=#{hios_id}&active_year=#{active_year}&coverage_kind=#{coverage_kind}"
        end

        #
        # get 'document/download/:bucket/:key'
        #
        def document_download_path bucket, key
          Rails.application.routes.url_helpers.document_download_path bucket, key
        end

        #
        # post :verify_identity
        #
        def verify_identity_path
          "#{BASE}/verify_identity"
        end

        #
        # post :verify_identity/answers
        #
        def verify_identity_answers_path
          verify_identity_path.concat '/answers'
        end

        #
        # get :check_user_existence
        #
        def check_user_existence
          "#{BASE}/check_user_existence"
        end

      end
    end
  end
end