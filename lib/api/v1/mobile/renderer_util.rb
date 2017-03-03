module Api
  module V1
    module Mobile
      module RendererUtil
        NO_BROKER_AGENCY_PROFILE_FOUND = 'no broker agency profile or broker role found'
        NO_EMPLOYER_DETAILS_FOUND = 'no employer details found'
        NO_EMPLOYEE_ROSTER_FOUND = 'no employee roster found'
        NO_INDIVIDUAL_DETAILS_FOUND = 'no individual details found'

        def render_broker response
          render json: response
        end

        def render_employer_details details
          render json: details
        end

        def render_employee_roster employer_profile, employees
          render json: {
              employer_name: employer_profile.legal_name,
              total_num_employees: employees.size,
              roster: EmployeeUtil.new(employees: employees.limit(500).to_a, employer_profile: employer_profile).roster_employees}
        end

        def render_individual_details person
          render json: IndividualUtil.new(person: person).build_individual_json
        end

        def report_broker_error status='not_found'
          render json: {error: NO_BROKER_AGENCY_PROFILE_FOUND}, status: status
        end

        def report_individual_error
          report_error NO_INDIVIDUAL_DETAILS_FOUND
        end

        def report_employer_error
          report_error NO_EMPLOYER_DETAILS_FOUND
        end

        def report_employee_error
          report_error NO_EMPLOYEE_ROSTER_FOUND
        end

        #
        # Private
        #
        private

        def report_error message
          render json: {error: message}, status: :not_found
        end

      end
    end
  end
end