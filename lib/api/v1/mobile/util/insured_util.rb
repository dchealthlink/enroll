module Api
  module V1
    module Mobile::Util
      class InsuredUtil < BaseUtil
        include Api::V1::Mobile::Insured::InsuredPerson
        include Api::V1::Mobile::Insured::InsuredEmployee

        def build_insured_json
          merge_all_this basic_person(@person), addresses, ie_employments(@person), ie_enrollments(@person), dependents
        end

        #
        # Private
        #
        private

        def merge_all_this *details
          hash = {}
          details.each { |m| hash.merge! JSON.parse(m) }
          hash
        end

        def addresses
          Jbuilder.encode do |json|
            json.addresses(@person.addresses) do |address|
              json.kind address.kind
              json.address_1 address.address_1
              json.address_2 address.address_2
              json.city address.city
              json.county address.county
              json.state address.state
              json.location_state_code address.location_state_code
              json.zip address.zip
              json.country_name address.country_name
            end
          end
        end

        def dependents
          Jbuilder.encode do |json|
            employee_role = @person.employee_roles.first
            employee_role.census_employee.tap do |employee|
              json.dependents include_dependents_to employee
            end if employee_role
          end
        end

      end
    end
  end
end