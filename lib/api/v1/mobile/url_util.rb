module Api
  module V1
    module Mobile
      module UrlUtil
        BASE = '/api/v1/mobile'

        #
        # get :broker
        #
        def broker_url
          "#{BASE}/broker"
        end

        #
        # get 'broker_agency_profile_id/:broker_agency_profile_id', action: :broker
        #
        def broker_with_broker_agency_url broker_agency_profile_id
          "#{BASE}/broker_agency_profile_id/#{broker_agency_profile_id}"
        end

        #
        # get 'employers/:employer_profile_id/details', action: :employer_details
        #
        def employers_details_url employer_profile_id
          "#{BASE}/employers/#{employer_profile_id}/details"
        end

        #
        # get 'employers/:employer_profile_id/employees', action: :employee_roster
        #
        def employers_employees_url employer_profile_id
          "#{BASE}/employers/#{employer_profile_id}/employees"
        end

        #
        # get 'employer/details', action: :my_employer_details
        #
        def employer_details_url
          "#{BASE}/employer/details"
        end

        #
        # get 'employer/employees', action: :my_employee_roster
        #
        def employees_url
          "#{BASE}/employer/employees"
        end

      end
    end
  end
end