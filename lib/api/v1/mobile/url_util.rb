module Api
  module V1
    module Mobile
      module UrlUtil
        BASE = '/api/v1/mobile'

        #
        # get :employers
        #
        def employers_url
          "#{BASE}/employers"
        end

        #
        # get 'employers/broker-agency-profile/:broker_agency_profile_id', action: :employers
        #
        def employers_with_broker_agency_url broker_agency_profile_id
          "#{BASE}/employers/broker-agency-profile/#{broker_agency_profile_id}"
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
        # get :employees, action: :my_employee_roster
        #
        def employees_url
          "#{BASE}/employees"
        end

      end
    end
  end
end