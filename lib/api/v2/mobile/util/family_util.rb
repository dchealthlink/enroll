module Api
  module V2
    module Mobile::Util
      class FamilyUtil < Api::V2::Mobile::Base

        def family_hbx_enrollments
          begin
            families = ->() {
              Family.where(:'households.hbx_enrollments'.elem_match => {
                :'benefit_group_assignment_id'.in => @benefit_group_assignment_ids,
                :aasm_state.in => @aasm_states,
                :kind => 'employer_sponsored',
                :coverage_kind => 'health',
                :is_active => true
              })
            }
          end

          families.call.map { |f| f.households.map { |h| h.hbx_enrollments } }.flatten.compact
        end

      end
    end
  end
end