module Api
  module V1
    module Mobile::Util
      class DependentUtil < Api::V1::Mobile::Base

        def initialize args={}
          super args
          @person = @employee.try(:employee_role).try(:person) if @employee
        end

        def include_dependents
          begin
            census_dependents = ->() {
              dependents = if @employee
                             @employee.census_dependents
                           else
                             @person.employee_roles.first.census_employee.census_dependents unless @person.employee_roles.empty?
                           end
              dependents || []
            }

            relationship_with = ->(dependent) {
              dependent.try(:relationship) || dependent.try(:employee_relationship)
            }

            family_dependents = ->() {
              all_family_dependents = @person.try(:primary_family).try(:active_family_members) || []
              all_family_dependents.reject { |d| relationship_with[d] == 'self' }
            }

            all_dependents = ->() {
              (family_dependents.call + census_dependents.call).uniq { |p| p.ssn }
            }
          end

          all_dependents.call.map { |d|
            JSON.parse(
              Api::V1::Mobile::Insured::InsuredPerson.new(person: d).basic_person).merge(relationship: relationship_with[d])
          }
        end

      end
    end
  end
end