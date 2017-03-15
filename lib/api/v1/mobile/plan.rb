module Api
  module V1
    module Mobile
      class Plan < Base

        #TODO: Temporary changes to help initiate discussions with Ben.
        def all_plans coverage_kind, active_year, tax_household: nil
          plans = ::Plan.individual_plans(coverage_kind: coverage_kind, active_year: active_year, tax_household: tax_household)
          plans ? plans.by_plan_ids(_elected_plan_ids).entries : [{}]
        end

        #
        # Private
        #
        private

        def _elected_plan_ids
          _benefit_packages.map(&:benefit_ids).flatten.uniq
        end

        def _benefit_packages
          ivl_bgs = []
          HbxProfile.current_hbx.benefit_sponsorship.current_benefit_period.benefit_packages.each { |bg|
            # TODO: Does any type of filtering need to happen here?
            ivl_bgs << bg
          }
          ivl_bgs.uniq
        end

      end
    end
  end
end