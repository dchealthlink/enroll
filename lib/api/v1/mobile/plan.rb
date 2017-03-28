module Api
  module V1
    module Mobile
      class Plan < Base
        include Api::V1::Mobile::Response::PlanResponse
        include ApplicationHelper

        def initialize args={}
          super args
          @ages = @ages.split(',').map { |x| x.to_i } if @ages
        end

        #
        # Returns all the available plans that match the requested criteria.
        #
        def all_available_plans
          _response _individual_plans
        end

        #
        # Called by ApplicationHelper.display_carrier_logo via PlanResponse::_basic_plan_details
        #
        def image_tag source, options
          nok = Nokogiri::HTML ActionController::Base.helpers.image_tag source, options
          nok.at_xpath('//img/@src').value
        end

        #
        # Private
        #
        private

        def _individual_plans
          begin
            tax_household = ->() {
              TaxHousehold.new eligibility_determinations: [EligibilityDetermination.new(csr_eligibility_kind: @csr_kind)]
            }
          end

          ::Plan.individual_plans coverage_kind: @coverage_kind, active_year: @active_year, tax_household: tax_household.call
        end

        def _services_rates plan
          services_rates_path plan.hios_id, plan.active_year, @coverage_kind
        end

        def _deductible plan
          return unless plan.family_deductible
          deductible_text = plan.family_deductible.split(' ').map { |x| x[/\d+/] }.compact
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
                  @ages.each { |age|
                    add_family_member.call(family_members).tap { |family_member|
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
                  hbx_enrollment.effective_on = Time.now
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

          UnassistedPlanCostDecorator.new(plan, create_hbx_enrollment.call).total_employee_cost
        end

      end
    end
  end
end