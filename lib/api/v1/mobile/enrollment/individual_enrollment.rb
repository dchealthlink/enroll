module Api
  module V1
    module Mobile::Enrollment
      class IndividualEnrollment < BaseEnrollment

        def populate_enrollments dependent_count, apply_ivl_rules=false
          begin
            #
            # Add the health and dental enrollments but do not override the enrollment if we already have one
            # in the 'Enrolled' status.
            #
            add_health_and_dental = ->(start_on, enrollments) {
              response = {}
              __add_default_fields! start_on, start_on.at_end_of_year, response
              enrollments.each do |y| 
                unless __has_enrolled? response, y
                  __health_and_dental! response, y, dependent_count, apply_ivl_rules
                  if y.coverage_kind == "health" && y.is_shop? && y.employer_profile && y.employer_profile.id
                    response[:employer_profile_id] = y.employer_profile.id
                  end
                end
              end
              response
            }

            add_enrollments = ->() {
              enrollments = []
              @person.primary_family.tap {|family|
                family && family.households.each {|h|
                  BaseEnrollment.excluding_invisible(h.hbx_enrollments.show_enrollments_sans_canceled).group_by {|x| x.effective_on}.each {|x|
                    next unless apply_ivl_rules || __is_current_or_upcoming?(x.first)
                    enrollments << add_health_and_dental[x.first, x.last]
                  }
                }
              }
              enrollments
            }
          end

          [add_enrollments.call]
        end

        def self.specific_enrollment_fields enrollment, apply_ivl_rules=false
          {
            total_premium_without_aptc: enrollment.total_premium,
            total_premium: enrollment.total_premium - enrollment.applied_aptc_amount.cents/100.to_f,
            elected_aptc_pct: enrollment.elected_aptc_pct,
            applied_aptc_amount_in_cents: enrollment.applied_aptc_amount.cents,
          }
        end

      end
    end
  end
end