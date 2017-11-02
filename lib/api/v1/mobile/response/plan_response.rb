module Api
  module V1
    module Mobile::Response
      module PlanResponse
        include ApplicationHelper
        include Api::V1::Mobile::Util::UrlUtil

        #
        # Returns a list of available plans.
        #
        def response plans, active_year
          Jbuilder.encode do |json|
            json.array! _sort_plans(plans) do |sorted_plan|
              _render_plan_details! json, sorted_plan[:plan]
              _render_total_premium! json, sorted_plan
              _render_hios! json, sorted_plan[:plan]
              _render_links! json, sorted_plan[:plan]
            end
          end
        end


        #
        # Private
        #
        private

        def _sort_plans plans
          plans_with_premiums = []
          plans.each {|plan| plans_with_premiums << {plan: plan, monthly_premium: _total_premium(plan)}}
          plans_with_premiums.sort_by {|x| x[:monthly_premium]}
        end

        def _render_total_premium! json, sorted_plan
          json.cost do
            json.monthly_premium sorted_plan[:monthly_premium]
            json.deductible _deductible sorted_plan[:plan]
            json.deductible_text _deductible_text sorted_plan[:plan]
          end
        end

        def _render_plan_details! json, plan
          json.id plan.id
          json.active_year plan.active_year.to_s
          json.coverage_kind plan.coverage_kind
          json.dc_in_network plan.dc_in_network
          json.dental_level plan.dental_level
          json.is_active plan.is_active
          json.is_standard_plan plan.is_standard_plan
          json.market plan.market
          json.metal_level plan.metal_level
          json.maximum_age plan.maximum_age
          json.minimum_age plan.minimum_age
          json.name plan.name
          json.nationwide plan.nationwide
          json.plan_type plan.plan_type
          json.provider plan.provider
        end

        def _render_hios! json, plan
          json.hios do
            json.base_id plan.hios_base_id
            json.id plan.hios_id
          end
        end

        def _render_links! json, plan
          json.links do
            json.summary_of_benefits __summary_of_benefits_url plan
            json.provider_directory plan.provider_directory_url
            json.rx_formulary plan.rx_formulary_url
            json.carrier_logo display_carrier_logo Maybe.new plan
            json.services_rates _services_rates plan
          end
        end

      end
    end
  end
end
