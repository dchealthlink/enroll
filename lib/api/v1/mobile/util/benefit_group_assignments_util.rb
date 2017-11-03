module Api
  module V1
    module Mobile::Util
      class BenefitGroupAssignmentsUtil < Api::V1::Mobile::Base

        #
        # If there is more than 1 benefit group assignment for a single year, it will return the first one
        # that isn't in the 'initialized' state IF there is one. If not, it will return the first benefit group
        # assignment amongst the ones in the 'initialized' state.
        #
        def unique_by_year
          @assignments.group_by(&:start_on).map { |start, bgas_for_year|
            bga = bgas_for_year.detect { |bga| bga.aasm_state != :initialized.to_s }
            bga.present? ? bga : bgas_for_year.first
          }
        end

      end
    end
  end
end