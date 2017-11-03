module Api
  module V2
    module Mobile::Util
      class StaffUtil < Api::V2::Mobile::Base

        # Returns a hash of arrays of staff members, keyed by employer id
        def keyed_by_employer_id
          begin
            people = ->() {
              Person.where(:employer_staff_roles => {
                  '$elemMatch' => {
                      employer_profile_id: {'$in': @employer_profiles.map(&:id)},
                      :aasm_state.ne => :is_closed
                  }
              })
            }
          end

          result = {}
          people.call.each { |staff|
            staff.employer_staff_roles.each { |role|
              result[role.employer_profile_id].nil? ? result[role.employer_profile_id] = [staff] :
                  result[role.employer_profile_id] <<= staff
            }
          }
          result.compact
        end

      end
    end
  end
end