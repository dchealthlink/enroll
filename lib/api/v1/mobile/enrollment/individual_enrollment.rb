module Api
  module V1
    module Mobile::Enrollment
      class IndividualEnrollment < BaseEnrollment

        def populate_enrollments
          begin
            has_enrolled = ->(response, enrollment) {
              response[enrollment.coverage_kind.to_sym] &&
                response[enrollment.coverage_kind.to_sym][:status] == EnrollmentConstants::ENROLLED
            }

            #
            # Add the health and dental enrollments but do not override the enrollment if we already have one
            # in the 'Enrolled' status.
            #
            add_health_and_dental = ->(start_on, enrollments) {
              response = {}
              __add_default_fields! start_on, response
              enrollments.each {|y| __health_and_dental! response, y unless has_enrolled[response, y]}
              response
            }

            add_enrollments = ->(enrollments) {
              @person.primary_family.tap {|family|
                family && family.households.each {|h|
                  h.hbx_enrollments.show_enrollments_sans_canceled.group_by {|x| x.effective_on}.each {|x|
                    next unless __is_current_or_upcoming? x.first
                    enrollments << add_health_and_dental[x.first, x.last]
                  }
                }
              }
            }
          end

          enrollments = []
          add_enrollments[enrollments]
          enrollments
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