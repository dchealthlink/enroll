module Api
  module V1
    module Mobile::Insured
      class InsuredIndividual < InsuredPerson
        Mobile = Api::V1::Mobile

        def ins_enrollments
          result = []
          enrollment = Mobile::Enrollment::IndividualEnrollment.new person: @person
          result << enrollment.populate_enrollments
          result
        end

      end
    end
  end
end