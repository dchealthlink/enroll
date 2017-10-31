require 'open-uri'

module Api
  module V1
    module Mobile
      class Plan < Base
        include Api::V1::Mobile::Response::PlanResponse
        include ApplicationHelper

        HBX_ROOT = "https://dchealthlink.com"
        DRUPAL_PLANS_URL = "https://dchealthlink.com/individuals/plan-info/health-plans/json"

        def initialize args={}
          super args
          @ages = @ages.split(',').map {|x| x.to_i} if @ages
        end

        #
        # Returns all the available plans that match the requested criteria.
        #
        def all_available_plans
          begin
            tax_household = ->() {
              TaxHousehold.new eligibility_determinations: [EligibilityDetermination.new(csr_eligibility_kind: @csr_kind)]
            }

            individual_plans = ->() {
              ::Plan.individual_plans coverage_kind: @coverage_kind, active_year: @active_year, tax_household: tax_household.call
            }
          end

          response _filter_catastrophic_plans(individual_plans.call), @active_year
        end

        #
        # Private
        #
        private

        # If any of the ages is > 29, we don’t show catastrophic plans.
        def _filter_catastrophic_plans plans
          @ages.select {|x| x > CATASTROPHIC::AGE_CAP}.present? ? plans.reject {|plan| plan.metal_level == CATASTROPHIC::METAL_LEVEL} :
            plans
        end

        def _services_rates plan
          services_rates_path plan.hios_id, plan.active_year, @coverage_kind
        end

        def _deductible plan
          return unless plan.family_deductible
          deductible_text = plan.family_deductible.split(' ').map {|x| x[/\d+/]}.compact
          deductible = @ages.size > 1 ? deductible_text.last : deductible_text.first
          deductible.to_i
        end

        def _deductible_text plan
          plan.family_deductible
        end

        def _total_premium plan
          begin
            create_hbx_enrollment = ->() {
              begin
                add_members = ->() {
                  begin
                    add_family_member = ->(family_members) {
                      family_member = FamilyMember.new
                      family_member.person = Person.new
                      family_members << family_member
                      family_member
                    }

                    add_hbx_enrollment_member = ->(age, family_member, hbx_enrollment_members) {
                      hbx_enrollment_member = HbxEnrollmentMember.new
                      hbx_enrollment_member.instance_variable_set :@age_on_effective_date, age
                      hbx_enrollment_member.applicant_id = family_member.id
                      hbx_enrollment_members << hbx_enrollment_member
                    }
                  end

                  hbx_enrollment_members = []
                  family_members = []
                  @ages.each {|age|
                    add_family_member.call(family_members).tap {|family_member|
                      add_hbx_enrollment_member.call age, family_member, hbx_enrollment_members
                    }
                  }
                  return family_members, hbx_enrollment_members
                }

                family_instance = ->(family_members) {
                  family = Family.new
                  family.family_members = family_members
                  family
                }

                hbx_enrollment_instance = ->(hbx_enrollment_members) {
                  hbx_enrollment = HbxEnrollment.new
                  hbx_enrollment.hbx_enrollment_members = hbx_enrollment_members
                  hbx_enrollment.effective_on = Date.new @active_year.to_i
                  hbx_enrollment
                }

                household_instance = ->(family) {
                  household = Household.new
                  household.family = family
                  household
                }
              end

              family_members, hbx_enrollment_members = add_members.call
              family = family_instance.call family_members
              hbx_enrollment = hbx_enrollment_instance.call hbx_enrollment_members
              hbx_enrollment.household = household_instance.call family
              hbx_enrollment
            }
          end

          raise "active year required" unless @active_year
          raise "please provide a comma-separated list of ages of covered individuals" unless @ages.present?
          raise "coverage_kind required" unless @coverage_kind
          UnassistedPlanCostDecorator.new(plan, create_hbx_enrollment.call).total_employee_cost
        end


        def _fetch_ivl_health_pdfs_by_hios_id plan_year
          
          ivl_plans = []
          result = open(DRUPAL_PLANS_URL).try(:read) 
          if result 
            parsed = JSON.parse result 
            if parsed
              ivl_plans = parsed.select do |x| 
                x['group_year'] == "#{plan_year} Individual" && x['is_health'].to_i == 1 && x['enabled'].to_i == 1
              end 
            end
          end
          Hash[ivl_plans.map do |p| 
             pdf = p["pdf_file"]
             link = pdf ? "#{HBX_ROOT}#{pdf}" : nil
             [p["hios_id"], link]
          end]
        end

        module CATASTROPHIC
          METAL_LEVEL = 'catastrophic'
          AGE_CAP = 29
        end
      end
    end
  end
end