module Api
  module V1
    module Mobile::Enrollment
      class IndividualEnrollment < BaseEnrollment

        def populate_enrollments
          final = []
          @person.primary_family.tap { |family|
            # __health_and_dental! result, family.households.map(&:hbx_enrollments).flatten if family
            if family
              family.households.each{|h|
                h.hbx_enrollments.show_enrollments_sans_canceled.each{|x|
                  result = {}
                  result[:start_on] = x.effective_on
                  __health_and_dental! result, [x]
                  final << result
                }
              }
            end
          }
          # result
          final
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