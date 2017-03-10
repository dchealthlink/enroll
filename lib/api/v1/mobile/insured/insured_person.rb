module Api
  module V1
    module Mobile::Insured
      class InsuredPerson < Api::V1::Mobile::Base

        def basic_person
          Jbuilder.encode do |json|
            json.first_name @person.first_name
            json.middle_name @person.middle_name
            json.last_name @person.last_name
            json.name_suffix @person.name_sfx
            json.date_of_birth @person.dob
            json.ssn_masked ssn_masked @person
            json.gender @person.gender
            json.id @person.id
          end
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

        def ins_dependents
          Jbuilder.encode do |json|
            json.dependents Api::V1::Mobile::Util::DependentUtil.new(person: @person).include_dependents
          end
        end

      end
    end
  end
end