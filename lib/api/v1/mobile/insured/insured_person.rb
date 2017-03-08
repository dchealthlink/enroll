module Api
  module V1
    module Mobile::Insured
      module InsuredPerson

        def basic_person person
          Jbuilder.encode do |json|
            json.first_name person.first_name
            json.middle_name person.middle_name
            json.last_name person.last_name
            json.name_suffix person.name_sfx
            json.date_of_birth person.dob
            json.ssn_masked ssn_masked person
            json.gender person.gender
            json.id person.id
          end
        end

        def include_dependents_to person
          dependents_of(person).map do |d|
            JSON.parse(basic_person(d)).merge(relationship: relationship_with(d))
          end
        end

        #
        # Private
        #
        private

        def dependents_of person
          all_family_dependents = person.try(:employee_role).try(:person).try(:primary_family).try(:active_family_members) || []
          family_dependents = all_family_dependents.reject { |d| relationship_with(d) == 'self' }
          census_dependents = person.census_dependents || []
          (family_dependents + census_dependents).uniq { |p| p.ssn }
        end

        def relationship_with dependent
          dependent.try(:relationship) || dependent.try(:employee_relationship)
        end

        def ssn_masked person
          "***-**-#{person.ssn[5..9]}" if person.ssn
        end

      end
    end
  end
end