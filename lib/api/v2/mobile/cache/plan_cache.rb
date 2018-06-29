module Api
  module V2
    module Mobile::Cache
      class PlanCache < Api::V2::Mobile::Base

        #
        # Note: The sequence of execution is absolutely critical in the caching code below so please do the necessary
        # testing when you make any changes to it.
        #
        def plan_and_benefit_group
          begin
            execute = ->(&block) {
              begin
                block.call
              rescue StandardError => e
                Rails.logger.error "Exception caught in plan_and_benefit_group: #{e.message}"
                e.backtrace.each { |line| Rails.logger.error line }
                {}
              end
            }
          end

          execute.call {
            begin
              hbx_enrollments = ->() {
                @enrollments_for_benefit_groups ||= Family.where(:'households.hbx_enrollments'.elem_match => {
                  :'benefit_group_assignment_id'.in => @benefit_group_assignment_ids
                }).map { |f| f.households.map { |h| h.hbx_enrollments.show_enrollments_sans_canceled } }.flatten.compact
              }

              employees_benefits = ->() {
                @employees_benefits ||= @employees.map do |e|
                  {"#{e.id}" => e, benefit_group_assignments: e.benefit_group_assignments.select do |bga|
                    bga.is_active? || TimeKeeper.date_of_record < bga.start_on
                  end}
                end.flatten
              }

              grouped_hbx_enrollments = ->() {
                @benefit_group_assignment_ids = employees_benefits.call.map { |x| x[:benefit_group_assignments] }.flatten.map(&:id)
                @grouped_bga_enrollments ||= hbx_enrollments.call.group_by { |x| x.benefit_group_assignment_id.to_s }
              }

              cache_result = ->() {
                {employees_benefits: employees_benefits.call, grouped_bga_enrollments: grouped_hbx_enrollments.call}
              }

              benefit_groups = ->() {
                @benefit_groups ||= @employer_profile.plan_years.map { |p| p.benefit_groups }.flatten.compact.index_by(&:id)
              }

              indexed_plans = ->() {
                @indexed_plans ||= ::Plan.where(:'id'.in => hbx_enrollments.call.map { |x| x.plan_id }.flatten).index_by(&:id)
              }

              populate_cache = ->() {
                hbx_enrollments.call.map { |e|
                  e.plan = indexed_plans.call()[e.plan_id] if e.plan_id
                  e.benefit_group = benefit_groups.call()[e.benefit_group_id] if e.benefit_group_id
                }
              }
            end

            grouped_hbx_enrollments.call
            populate_cache.call
            cache_result.call
          }
        end

      end
    end
  end
end
