module Api
  module V1
    module Mobile::Enrollment
      class IndividualEnrollment < BaseEnrollment

        def populate_enrollments
          result = {}
          @person.primary_family.tap { |family|
            __health_and_dental! result, family.households.map(&:hbx_enrollments).flatten if family
          }
          result
        end

        #
        # Protected
        #
        protected

        def __specific_enrollment_fields enrollment
          {
              elected_aptc_pct: enrollment.elected_aptc_pct,
              applied_aptc_amount_in_cents: enrollment.applied_aptc_amount.cents,
          }
        end

      end
    end
  end
end