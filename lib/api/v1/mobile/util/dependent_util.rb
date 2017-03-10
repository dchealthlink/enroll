module Api
  module V1
    module Mobile::Util
      class DependentUtil < Api::V1::Mobile::Base

        def initialize args={}
          super args
          @person = @employee.try(:employee_role).try(:person) if @employee
        end

        def include_dependents
          all_dependents.map do |d|
            JSON.parse(Api::V1::Mobile::Insured::InsuredPerson.new(person: d).basic_person).merge(relationship: relationship_with(d))
          end
        end

        #
        # Private
        #
        private

        def all_dependents
          (family_dependents + census_dependents).uniq { |p| p.ssn }
        end

        def census_dependents
          dependents = if @employee
                         @employee.census_dependents
                       else
                         @person.employee_roles.first.census_employee.census_dependents unless @person.employee_roles.empty?
                       end
          dependents || []
        end

        def family_dependents
          all_family_dependents = @person.try(:primary_family).try(:active_family_members) || []
          all_family_dependents.reject { |d| relationship_with(d) == 'self' }
        end

        def relationship_with dependent
          dependent.try(:relationship) || dependent.try(:employee_relationship)
        end

      end
    end
  end
end