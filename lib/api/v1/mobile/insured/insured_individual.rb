module Api
  module V1
    module Mobile::Insured
      class InsuredIndividual < InsuredPerson
        Mobile = Api::V1::Mobile

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