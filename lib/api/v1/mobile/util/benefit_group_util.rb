module Api
  module V1
    module Mobile::Util
      class BenefitGroupUtil < Api::V1::Mobile::Base
        attr_accessor :ids, :plan_year

        def initialize args={}
          super args
          @ids = @plan_year.benefit_groups.map(&:id) if @plan_year
        end

        def benefit_group_assignment_ids enrolled, waived, terminated
          begin
            bg_assignment_ids = ->(statuses) {
              begin
                active_employer_sponsored_health_enrollments = ->() {
                  @active_employer_sponsored_health_enrollments ||= @all_enrollments.select do |enrollment|
                    enrollment.kind == 'employer_sponsored' &&
                      enrollment.coverage_kind == 'health' &&
                      enrollment.is_active
                  end.compact.sort do |e1, e2|
                    e2.submitted_at.to_i <=> e1.submitted_at.to_i # most recently submitted first
                  end.uniq do |e|
                    e.benefit_group_assignment_id # only the most recent per employee
                  end
                }.call
              end

              @active_employer_sponsored_health_enrollments.select do |enrollment|
                statuses.include? (enrollment.aasm_state)
              end.map(&:benefit_group_assignment_id)
            }
          end

          yield bg_assignment_ids[enrolled], bg_assignment_ids[waived], bg_assignment_ids[terminated]
        end

        def census_members
          CensusMember.where(
            {"benefit_group_assignments.benefit_group_id" => {"$in" => @ids},
             :aasm_state => {'$in' => ['eligible', 'employee_role_linked']}
            })
        end

        def eligibility_rule
          case @benefit_group.effective_on_offset
            when 0
              'First of the month following or coinciding with date of hire'
            when 1
              'First of the month following date of hire'
            else
              "#{@benefit_group.effective_on_kind.humanize} following #{@benefit_group.effective_on_offset} days"
          end
        end

      end
    end
  end
end