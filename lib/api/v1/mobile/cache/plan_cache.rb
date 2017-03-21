module Api
  module V1
    module Mobile::Cache
      class PlanCache < Api::V1::Mobile::Base

        #
        # Note: The sequence of execution is absolutely critical in the caching code below so please do the necessary
        # testing when you make any changes to it.
        #
        def plan_and_benefit_group
          _execute {
            _grouped_hbx_enrollments
            _populate_cache
            _cache_result
          }
        end

        #
        # Private
        #
        private

        def _execute
          begin
            yield
          rescue Exception => e
            Rails.logger.error "Exception caught in plan_and_benefit_group: #{e.message}"
            e.backtrace.each { |line| Rails.logger.error line }
            {}
          end
        end

        def _grouped_hbx_enrollments
          @benefit_group_assignment_ids = _employees_benefits.map { |x| x[:benefit_group_assignments] }.flatten.map(&:id)
          @grouped_bga_enrollments ||= _hbx_enrollments.group_by { |x| x.benefit_group_assignment_id.to_s }
        end

        def _populate_cache
          _hbx_enrollments.map { |e|
            e.plan = _indexed_plans[e.plan_id] if e.plan_id
            e.benefit_group = _benefit_groups[e.benefit_group_id] if e.benefit_group_id
          }
        end

        def _cache_result
          {employees_benefits: _employees_benefits, grouped_bga_enrollments: _grouped_hbx_enrollments}
        end

        def _benefit_groups
          @benefit_groups ||= @employer_profile.plan_years.map { |p| p.benefit_groups }.flatten.compact.index_by(&:id)
        end

        def _indexed_plans
          @indexed_plans ||= ::Plan.where(:'id'.in => _hbx_enrollments.map { |x| x.plan_id }.flatten).index_by(&:id)
        end

        def _employees_benefits
          @employees_benefits ||= @employees.map do |e|
            {"#{e.id}" => e, benefit_group_assignments: e.benefit_group_assignments.select do |bga|
              bga.is_active? || TimeKeeper.date_of_record < bga.start_on
            end}
          end.flatten
        end

        def _hbx_enrollments
          @enrollments_for_benefit_groups ||= Family.where(:'households.hbx_enrollments'.elem_match => {
              :'benefit_group_assignment_id'.in => @benefit_group_assignment_ids
          }).map { |f| f.households.map { |h| h.hbx_enrollments.show_enrollments_sans_canceled } }.flatten.compact
        end

      end
    end
  end
end
