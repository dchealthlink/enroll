module Api
  module V2
    module Mobile::Util
      class PlanYearUtil < Api::V2::Mobile::Base
        MAX_DENTAL_PLANS = 13
        attr_accessor :plan_year

        def open_enrollment?
          employee_max? && @as_of &&
            @plan_year.open_enrollment_start_on &&
            @plan_year.open_enrollment_end_on &&
            @plan_year.open_enrollment_contains?(@as_of)
        end

        def employee_max?
          begin
            plan_year_employee_max = ->() {
              @plan_year.employer_profile.census_employees.count < 100
            }
          end

          @plan_year && plan_year_employee_max.call
        end

        def plan_offerings
          @plan_year.benefit_groups.compact.map do |benefit_group|
            {
              benefit_group_name: benefit_group.title,
              eligibility_rule: BenefitGroupUtil.new(benefit_group: benefit_group).eligibility_rule,
              health: _health_offering(benefit_group),
              dental: _dental_offering(benefit_group)
            }
          end
        end

        def plan_year_details
          summary = plan_year_summary
          summary[:plan_offerings] = plan_offerings
          summary
        end

        def plan_year_summary
          renewals_offset_in_months = Settings.aca.shop_market.renewal_application.earliest_start_prior_to_effective_on.months
          {
            open_enrollment_begins: @plan_year.open_enrollment_start_on,
            open_enrollment_ends: @plan_year.open_enrollment_end_on,
            plan_year_begins: @plan_year.start_on,
            renewal_in_progress: @plan_year.is_renewing?,
            renewal_application_available: @plan_year.start_on >> renewals_offset_in_months,
            renewal_application_due: @plan_year.due_date_for_publish,
            state: @plan_year.aasm_state.to_s.humanize.titleize,
            minimum_participation_required: @plan_year.minimum_enrolled_count
          }
        end

        #
        # Private
        #
        private

        def _dental_offering benefit_group
          if benefit_group.is_offering_dental? && benefit_group.dental_reference_plan
            begin
              elected_dental_plans = ->(benefit_group) {
                benefit_group.elected_dental_plans.map {|p|
                  {carrier_name: p.carrier_profile.legal_name, plan_name: p.name}
                } if benefit_group.elected_dental_plan_ids.count < MAX_DENTAL_PLANS
              }
            end

            _render_plan_offering(
              plan: benefit_group.dental_reference_plan,
              plan_option_kind: benefit_group.plan_option_kind,
              relationship_benefits: benefit_group.dental_relationship_benefits,
              employer_estimated_max: benefit_group.monthly_employer_contribution_amount(benefit_group.dental_reference_plan),
              employee_estimated_min: benefit_group.monthly_min_employee_cost('dental'),
              employee_estimated_max: benefit_group.monthly_max_employee_cost('dental'),
              elected_dental_plans: elected_dental_plans[benefit_group]
            )
          end
        end

        def _health_offering benefit_group
          _render_plan_offering(
            plan: benefit_group.reference_plan,
            plan_option_kind: benefit_group.plan_option_kind,
            relationship_benefits: benefit_group.relationship_benefits,
            employer_estimated_max: benefit_group.monthly_employer_contribution_amount,
            employee_estimated_min: benefit_group.monthly_min_employee_cost,
            employee_estimated_max: benefit_group.monthly_max_employee_cost
          )
        end

        def _render_plan_offering plan: nil, plan_option_kind: nil, relationship_benefits: [], employer_estimated_max: 0,
                                  employee_estimated_min: 0, employee_estimated_max: 0, elected_dental_plans: nil
          begin
            render_plans_by = ->(rendered) {
              count_dental_plans = rendered[:elected_dental_plans].try(:count)
              plans_by, plans_by_summary_text =
                case rendered[:plan_option_kind]
                  when 'single_carrier'
                    ['All Plans From A Single Carrier', "All #{rendered[:carrier_name]} Plans"]
                  when 'metal_level'
                    ['All Plans From A Given Metal Level', "All #{rendered[:metal_level]} Level Plans"]
                  when 'single_plan'
                    if count_dental_plans.nil?
                      ['A Single Plan', 'Reference Plan Only']
                    else
                      [count_dental_plans < MAX_DENTAL_PLANS ? "Custom (#{ count_dental_plans } Plans)" : 'All Plans'] * 2
                    end
                end

              rendered[:plans_by] = plans_by
              rendered[:plans_by_summary_text] = plans_by_summary_text
              rendered
            }

            employer_contribution_by_relationship = ->(relationship_benefits) {
              Hash[relationship_benefits.map do |rb|
                [rb.relationship, rb.offered ? rb.premium_pct : nil]
              end]
            }

            # "copied from web app to support obsolete metal_level semantics"
            display_metal_level = ->(plan) {
              (plan.active_year == 2015 || plan.coverage_kind == 'health' ? plan.metal_level : plan.dental_level).try(:titleize)
            }
          end

          render_plans_by[
            reference_plan_name: plan.name.try(:upcase),
            reference_plan_HIOS_id: plan.hios_id,
            carrier_name: plan.carrier_profile.try(:legal_name),
            plan_type: plan.try(:plan_type).try(:upcase),
            metal_level: display_metal_level.call(plan),
            plan_option_kind: plan_option_kind,
            employer_contribution_by_relationship: employer_contribution_by_relationship.call(relationship_benefits),
            elected_dental_plans: elected_dental_plans,
            estimated_employer_max_monthly_cost: employer_estimated_max,
            estimated_plan_participant_min_monthly_cost: employee_estimated_min,
            estimated_plan_participant_max_monthly_cost: employee_estimated_max
          ]
        end

      end
    end
  end
end