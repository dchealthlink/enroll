require "rails_helper"
require 'support/brady_bunch'
require 'lib/api/v1/support/mobile_employer_data'

RSpec.describe Api::V1::Mobile::Util::EmployerUtil, dbclean: :after_each do
  include_context 'employer_data'
  Util = Api::V1::Mobile::Util

  shared_examples 'organizations_by' do |desc|
    it "should #{desc}" do
      employer.employers_and_broker_agency
      organizations = employer.instance_variable_get :@organizations
      expect(organizations).to be_a_kind_of Mongoid::Criteria
      org = organizations.first
      expect(org).to be_a_kind_of Organization
      expect(org.hbx_id).to_not be_nil
      expect(org.legal_name).to_not be_nil
      expect(org.fein).to_not be_nil
      expect(org.dba).to_not be_nil
    end
  end

  context 'Employer Profile' do
    it 'should return the employer profile' do
      staff_role = FactoryGirl.create(:employer_staff_role, employer_profile_id: employer_profile_cafe.id)
      allow(user.person).to receive(:employer_staff_roles).and_return([staff_role])
      employer_profile = Util::EmployerUtil.employer_profile_for_user user
      expect(employer_profile).to be_a_kind_of EmployerProfile
    end
  end

  context 'Enrollment Status' do

    it 'initializes the plan year' do
      employer = Util::EmployerUtil.new user: user, employer_profile: employer_profile_cafe
      plan_years = employer.instance_variable_get(:@plan_years)
      expect(plan_years.count).to eq 1
      expect(plan_years[0]).to be_a_kind_of PlanYear
    end

    it_behaves_like 'organizations_by', 'get organization by broker agency profile' do
      let!(:employer) {
        allow(employer_profile).to receive(:broker_agency_accounts).and_return([broker_agency_account])
        Util::EmployerUtil.new user: user, authorized: {broker_agency_profile: broker_agency_profile}
      }
    end

    it_behaves_like 'organizations_by', 'get organization by broker role' do
      let!(:employer) {
        allow(employer_profile2).to receive(:broker_agency_accounts).and_return([broker_agency_account2])
        Util::EmployerUtil.new user: user, authorized: {broker_role: broker_role}
      }
    end

    it 'should not return employee enrolled, waived and terminated counts when not in open enrollment' do
      employer = Util::EmployerUtil.new user: user, employer_profile: employer_profile
      summary = employer.send(:_summary_details, {employer_profile: employer_profile_salon, years: employer_profile_salon.plan_years, include_enrollment_counts: true, include_details_url: true})
      plan_year = summary[:plan_years].first
      expect(plan_year).to include(:minimum_participation_required)
      expect(plan_year[:minimum_participation_required]).to eq 1
      expect(plan_year).not_to include(:employees_enrolled, :employees_waived, :employees_terminated)
    end

    it 'should return employee enrolled, waived and terminated counts when in open enrollment' do
      employer = Util::EmployerUtil.new user: user, employer_profile: employer_profile
      allow_any_instance_of(Util::PlanYearUtil).to receive(:open_enrollment?).and_return(true)
      summary = employer.send(:_summary_details, {employer_profile: employer_profile_cafe, years: employer_profile_cafe.plan_years, include_enrollment_counts: true, include_details_url: true})
      plan_year = summary[:plan_years].first
      expect(plan_year).to include(:minimum_participation_required, :employees_enrolled, :employees_waived, :employees_terminated)
      expect(plan_year[:minimum_participation_required]).to eq 2
      expect(plan_year[:employees_enrolled]).to eq 2
      expect(plan_year[:employees_waived]).to eq 0
      expect(plan_year[:employees_terminated]).to eq 0

      summary = employer.send(:_summary_details, {employer_profile: employer_profile_salon, years: employer_profile_salon.plan_years, include_enrollment_counts: true, include_details_url: true})
      plan_year = summary[:plan_years].first
      expect(plan_year).to include(:minimum_participation_required, :employees_enrolled, :employees_waived, :employees_terminated)
      expect(plan_year[:minimum_participation_required]).to eq 1
      expect(plan_year[:employees_enrolled]).to eq 1
      expect(plan_year[:employees_waived]).to eq 0
      expect(plan_year[:employees_terminated]).to eq 0
    end

    def confirm_expected_plan_year_summary_fields_for_cafe plan_year
      expect(plan_year[:open_enrollment_begins]).to eq Date.parse('2016-11-01')
      expect(plan_year[:open_enrollment_ends]).to eq Date.parse('2016-12-10')
      expect(plan_year[:plan_year_begins]).to eq Date.parse('2017-01-01')
      expect(plan_year[:renewal_application_available]).to eq Date.parse('2016-10-01')
      expect(plan_year[:renewal_application_due]).to eq Date.parse('2016-12-05')
      expect(plan_year[:renewal_in_progress]).to be_falsey
      expect(plan_year[:minimum_participation_required]).to eq 2
    end

    it 'should return the summary details,including URLs' do
      employer = Util::EmployerUtil.new user: user, employer_profile: employer_profile
      allow_any_instance_of(Util::PlanYearUtil).to receive(:open_enrollment?).and_return(true)
      summary = employer.send(:_summary_details, {employer_profile: employer_profile_cafe, years: employer_profile_cafe.plan_years, include_enrollment_counts: true, include_details_url: true})
      expect(summary).to include(:employer_name, :binder_payment_due, :employees_total, :plan_years,
                                 :employer_details_url, :employee_roster_url)
      expect(summary[:plan_years].first).to include(:minimum_participation_required,
                                                    :open_enrollment_begins, :open_enrollment_ends, :plan_year_begins,
                                                    :renewal_application_available, :renewal_application_due,
                                                    :renewal_in_progress, :state)

      expect(summary[:employer_name]).to eq employer_profile_cafe.legal_name
      expect(summary[:employees_total]).to eq 0

      expect(summary[:employer_details_url]).to match(/\/api\/v1\/mobile\/employers\/[0-9a-f]{24}\/details/)
      expect(summary[:employee_roster_url]).to match(/\/api\/v1\/mobile\/employers\/[0-9a-f]{24}\/employees/)
      confirm_expected_plan_year_summary_fields_for_cafe summary[:plan_years].first

      summary = employer.send(:_summary_details, {
        employer_profile: employer_profile_cafe,
        years: employer_profile_cafe.plan_years,
        staff: [FactoryGirl.create(:person)], offices: [FactoryGirl.build(:office_location)]
      })
      expect(summary).to include(:contact_info)
      contact_info = summary[:contact_info]
      expect(contact_info).to be_a_kind_of Array
      expect(contact_info.size).to eq 2
      offices = contact_info.last
      staff = contact_info.first
      expect(staff).to include(:first, :last, :phone, :mobile, :emails)
      expect(offices).to include(:first, :last, :phone, :address_1, :address_2, :city, :state, :zip)
      expect(staff[:emails]).to be_a_kind_of Array
      expect(staff[:first]).to_not be_nil
      expect(staff[:last]).to_not be_nil
      expect(offices[:first]).to_not be_nil
      expect(offices[:last]).to_not be_nil
      expect(offices[:phone]).to_not be_nil
      expect(offices[:address_1]).to_not be_nil
      expect(offices[:address_2]).to_not be_nil
      expect(offices[:city]).to_not be_nil
      expect(offices[:state]).to_not be_nil
      expect(offices[:zip]).to_not be_nil
    end

    it 'should return the details' do
      employer = Util::EmployerUtil.new user: user, employer_profile: employer_profile_cafe
      summary = employer.employer_details

      expect(summary).to include(:employer_name, :binder_payment_due, :employees_total, :plan_years,
                                 :active_general_agency)
      expect(summary[:plan_years].first).to include(:minimum_participation_required,
                                                    :open_enrollment_begins, :open_enrollment_ends, :plan_year_begins,
                                                    :renewal_application_available, :renewal_application_due,
                                                    :renewal_in_progress, :state, :plan_offerings)
      expect(summary[:plan_years].first[:plan_offerings].count).to eq 2
      expect(summary[:plan_years].first[:plan_offerings].first).to include(:benefit_group_name, :eligibility_rule, :health, :dental)

      confirm_expected_plan_year_summary_fields_for_cafe summary[:plan_years].first
    end

    it 'returns employer details' do
      employer = Util::EmployerUtil.new employer_profile: employer_profile_cafe, report_date: TimeKeeper.date_of_record
      details = employer.employer_details
      expect(details).to include(:employer_name, :binder_payment_due, :employees_total, :plan_years,
                                 :active_general_agency)
      expect(details[:plan_years].first).to include(:minimum_participation_required,
                                                    :open_enrollment_begins, :open_enrollment_ends, :plan_year_begins,
                                                    :renewal_application_available, :renewal_application_due,
                                                    :renewal_in_progress, :state, :plan_offerings)
      confirm_expected_plan_year_summary_fields_for_cafe details[:plan_years].first
      expect(details[:plan_years].first[:plan_offerings].count).to eq 2
      active = details[:plan_years].first[:plan_offerings].first
      expect(active).to include(:benefit_group_name, :eligibility_rule, :health, :dental)
      expect(active[:benefit_group_name]).to include 'collar'
      expect(active[:eligibility_rule]).to eq 'First of the month following or coinciding with date of hire'
      expect(active[:health]).to include(:reference_plan_name, :reference_plan_HIOS_id, :carrier_name,
                                         :plan_type, :metal_level, :plan_option_kind)

      expect(active[:health][:reference_plan_name]).to include 'BLUECHOICE SILVER'
      expect(active[:health][:reference_plan_HIOS_id]).to include '41842DC04000'
      expect(active[:health][:carrier_name]).to eq 'United Health Care'
      expect(active[:health][:plan_type]).to eq 'POS'
      expect(active[:health][:metal_level]).to eq 'Silver'
      expect(active[:health][:plan_option_kind]).to eq 'single_plan'

      expect(active[:health][:employer_contribution_by_relationship]).to include('employee', 'spouse', 'domestic_partner',
                                                                                 'child_under_26', 'disabled_child_26_and_over',
                                                                                 'child_26_and_over')
      expect(active[:health][:employer_contribution_by_relationship]['employee']).to eq 80.0
      expect(active[:health][:employer_contribution_by_relationship]['spouse']).to eq 40.0
      expect(active[:health][:employer_contribution_by_relationship]['domestic_partner']).to eq 40.0
      expect(active[:health][:employer_contribution_by_relationship]['child_under_26']).to eq 40.0
      expect(active[:health][:employer_contribution_by_relationship]['disabled_child_26_and_over']).to eq 40.0

      expect(active[:health][:estimated_employer_max_monthly_cost]).to eq 0.0
      expect(active[:health][:estimated_plan_participant_min_monthly_cost]).to eq 0.0
      expect(active[:health][:estimated_plan_participant_max_monthly_cost]).to eq 0.0
      expect(active[:health][:plans_by]).to eq 'A Single Plan'
      expect(active[:health][:plans_by_summary_text]).to eq 'Reference Plan Only'
    end

    it 'return employers and broker agency' do
      allow(Organization).to receive(:by_broker_agency_profile).and_return([organization])
      employer = Util::EmployerUtil.new authorized: {broker_agency_profile: broker_agency_profile, status: 200},
                                        user: user
      broker = employer.employers_and_broker_agency
      expect(broker).to include(:broker_name, :broker_agency, :broker_agency_id, :broker_clients)

      employers = broker[:broker_clients]
      expect(employers).to be_a_kind_of Array
      expect(employers.size).to eq 1

      employer = employers.first
      expect(employer[:employer_details_url]).to match(/\/api\/v1\/mobile\/employers\/[0-9a-f]{24}\/details/)
      expect(employer[:employee_roster_url]).to match(/\/api\/v1\/mobile\/employers\/[0-9a-f]{24}\/employees/)

      contact_information = employer[:contact_info]
      expect(contact_information).to be_a_kind_of Array
      expect(contact_information.size).to eq 2

      expect(contact_information.pop).to include(:first, :last, :phone, :address_1, :address_2, :city, :state, :zip)
    end

  end

  context "Enrollment counts for various scenarios" do
    include_context "BradyWorkAfterAll"

    before :each do
      create_brady_census_families
    end

    attr_reader :enrollment, :household, :mikes_coverage_household, :carols_coverage_household, :coverage_household
    let!(:mikes_renewing_plan_year) { FactoryGirl.create(:renewing_plan_year, employer_profile: mikes_employer, benefit_groups: [mikes_benefit_group]) }

    before(:each) do
      @household = mikes_family.households.first
      @coverage_household1 = household.coverage_households[0]
      @coverage_household2= household.coverage_households[1]

      @enrollment1 = household.create_hbx_enrollment_from(
        employee_role: mikes_employee_role,
        coverage_household: @coverage_household1,
        benefit_group: mikes_benefit_group,
        benefit_group_assignment: @mikes_benefit_group_assignments
      )
      @enrollment1.save

      @enrollment2 = household.create_hbx_enrollment_from(
        employee_role: mikes_employee_role,
        coverage_household: @coverage_household2,
        benefit_group: mikes_benefit_group,
        benefit_group_assignment: @carols_benefit_group_assignments
      )
      @enrollment2.save
    end

    it "should count enrollment for two waived in the same family" do
      @enrollment1.update_attributes(aasm_state: "inactive")
      @enrollment2.update_attributes(aasm_state: "inactive")
      benefit_group_assignment = [@mikes_benefit_group_assignments, @carols_benefit_group_assignments]
      employee = Util::EmployeeUtil.new benefit_group_assignments: benefit_group_assignment
      result = employee.send(:count_by_enrollment_status)
      expect(result).to eq [0, 2, 0]
    end


    it "should count enrollment for two enrolled in the same family" do
      @enrollment1.update_attributes(aasm_state: "coverage_enrolled")
      @enrollment2.update_attributes(aasm_state: "coverage_enrolled")
      benefit_group_assignment = [@mikes_benefit_group_assignments, @carols_benefit_group_assignments]
      employee = Util::EmployeeUtil.new benefit_group_assignments: benefit_group_assignment
      result = employee.send(:count_by_enrollment_status)
      expect(result).to eq [2, 0, 0]
    end


    it "should count enrollment for one enrolled and one waived in the same family" do
      @enrollment2.waive_coverage_by_benefit_group_assignment("inactive")
      @enrollment1.update_attributes(aasm_state: "coverage_enrolled")
      benefit_group_assignment = [@mikes_benefit_group_assignments, @carols_benefit_group_assignments]
      employee = Util::EmployeeUtil.new benefit_group_assignments: benefit_group_assignment
      result = employee.send(:count_by_enrollment_status)
      expect(result).to eq [1, 1, 0]
    end

    it "people with shopped-for-but-not-bought or terminated policies" do
      @enrollment2.update_attributes(aasm_state: "coverage_terminated")
      benefit_group_assignment = [@mikes_benefit_group_assignments, @carols_benefit_group_assignments]
      employee = Util::EmployeeUtil.new benefit_group_assignments: benefit_group_assignment
      result = employee.send(:count_by_enrollment_status)
      expect(result).to eq [0, 0, 1]
    end

    it "Should count enrollment for the person not enrolled this year but already enrolled for next year if looking at next year" do
      @mikes_benefit_group_assignments.update_attributes(start_on: mikes_renewing_plan_year.start_on, aasm_state: "coverage_renewed")
      @household = mikes_family.households.first
      @coverage_household1 = household.coverage_households[0]

      @enrollment1 = household.create_hbx_enrollment_from(
        employee_role: mikes_employee_role,
        coverage_household: @coverage_household1,
        benefit_group: mikes_benefit_group,
        benefit_group_assignment: @mikes_benefit_group_assignments,
      )
      @enrollment1.save
      @enrollment1.update_attributes(aasm_state: "renewing_coverage_enrolled")


      benefit_group_assignment = [@mikes_benefit_group_assignments]
      employee = Util::EmployeeUtil.new benefit_group_assignments: benefit_group_assignment
      result = employee.send(:count_by_enrollment_status)
      expect(result).to eq [0, 0, 0]
    end

    it "Should count enrollment for person enrolled this year but already waived for next year if looking at next year" do
      @household = mikes_family.households.first
      @coverage_household1 = household.coverage_households[0]

      @enrollment1 = household.create_hbx_enrollment_from(
        employee_role: mikes_employee_role,
        coverage_household: @coverage_household1,
        benefit_group: mikes_benefit_group,
        benefit_group_assignment: @mikes_benefit_group_assignments,
      )
      @enrollment1.save
      @enrollment1.waive_coverage_by_benefit_group_assignment("inactive")

      benefit_group_assignment = [@mikes_benefit_group_assignments]
      employee = Util::EmployeeUtil.new benefit_group_assignments: benefit_group_assignment
      result = employee.send(:count_by_enrollment_status)
      expect(result).to eq [0, 0, 0]

    end
  end

end

