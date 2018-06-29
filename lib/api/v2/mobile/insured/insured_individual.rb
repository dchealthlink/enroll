module Api
  module V2
    module Mobile::Insured
      class InsuredIndividual < InsuredPerson
        Mobile = Api::V2::Mobile

        def ins_enrollments dependent_count
          result = []
          enrollment = Mobile::Enrollment::IndividualEnrollment.new person: @person
          result << enrollment.populate_enrollments(dependent_count)
          result
        end

      end
    end
  end
end