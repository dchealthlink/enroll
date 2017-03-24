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
          ::Plan.individual_plans coverage_kind: @coverage_kind, active_year: @active_year, tax_household: _tax_household
        end

        def _services_rates plan
          services_rates_path plan.hios_id, plan.active_year, @coverage_kind
        end

        def _tax_household
          TaxHousehold.new eligibility_determinations: [EligibilityDetermination.new(csr_eligibility_kind: @csr_kind)]
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

        def _family?
          @ages.size > 1
        end

        def _total_premium plan
          UnassistedPlanCostDecorator.new(plan, _create_hbx_enrollment).total_employee_cost
        end

        def _create_hbx_enrollment
          family_members, hbx_enrollment_members = _add_members
          family = _family_instance family_members
          hbx_enrollment = _hbx_enrollment_instance hbx_enrollment_members
          hbx_enrollment.household = _household_instance family
          hbx_enrollment
        end

        def _add_members
          hbx_enrollment_members = []
          family_members = []
          @ages.each { |age|
            _add_family_member!(family_members) { |family_member|
              _add_hbx_enrollment_member! age, family_member, hbx_enrollment_members
            }
          }
          return family_members, hbx_enrollment_members
        end

        def _hbx_enrollment_instance hbx_enrollment_members
          hbx_enrollment = HbxEnrollment.new
          hbx_enrollment.hbx_enrollment_members = hbx_enrollment_members
          hbx_enrollment.effective_on = Time.now
          hbx_enrollment
        end

        def _family_instance family_members
          family = Family.new
          family.family_members = family_members
          family
        end

        def _household_instance family
          household = Household.new
          household.family = family
          household
        end

        def _add_hbx_enrollment_member! age, family_member, hbx_enrollment_members
          hbx_enrollment_member = HbxEnrollmentMember.new
          hbx_enrollment_member.instance_variable_set :@age_on_effective_date, age
          hbx_enrollment_member.applicant_id = family_member.id
          hbx_enrollment_members << hbx_enrollment_member
        end

        def _add_family_member! family_members
          family_member = FamilyMember.new
          family_member.person = Person.new
          family_members << family_member
          yield family_member
        end

      end
    end
  end
end