require "rails_helper"
require 'support/brady_bunch'
require 'lib/api/v1/support/mobile_employer_data'
require 'lib/api/v1/support/mobile_employee_data'

RSpec.describe Api::V1::Mobile::Util::EmployeeUtil, dbclean: :after_each do
  include_context 'employer_data'
  Util = Api::V1::Mobile::Util

  shared_examples 'roster_employees' do |desc|
    include_context 'employee_data'

    it "should #{desc}" do
      expect(ce_employee.active_benefit_group_assignment).to_not be nil
      expect(ce_employee.active_benefit_group_assignment.hbx_enrollments.count).to be > 0

      expect(emp).to include(:first_name, :middle_name, :last_name, :name_suffix, :gender, :date_of_birth,
                             :ssn_masked, :hired_on, :id, :is_business_owner, :enrollments)
      expect(emp[:first_name]).to eq "Robert"
      expect(emp[:middle_name]).to eq "Anson"
      expect(emp[:last_name]).to eq "Heinlein"
      expect(emp[:name_suffix]).to eq "Esq."
      expect(emp[:gender]).to eq "male"
      expect(emp[:date_of_birth]).to eq "1907-07-07"
      expect(emp[:ssn_masked]).to eq "***-**-6666"
      expect(emp[:hired_on]).to eq Date.parse("2008-12-08")
      expect(emp[:id]).to eq ce_employee.id
      expect(emp[:is_business_owner]).to be false

      expect(emp[:enrollments]).to be_a_kind_of Array
      expect(emp[:enrollments].size).to eq 1
      expect(emp[:enrollments][0]).to include('health', 'dental', :start_on)
      health = emp[:enrollments][0]["health"]
      expect(health).to_not be nil
      expect(health).to include(:status, :employer_contribution, :employee_cost, :total_premium,
                                :plan_name, :plan_type, :metal_level, :benefit_group_name)
      expect(health[:status]).to eq "Enrolled"

      dental = emp[:enrollments][0]["dental"]
      expect(dental).to include(:status, :employer_contribution, :employee_cost, :total_premium,
                                :plan_name, :plan_type, :metal_level, :benefit_group_name)
    end
  end

  context "Rendering employee" do
    include_context 'employee_data'

    it_behaves_like 'roster_employees', 'return the employee' do
      let!(:emp) {
        employee = Util::EmployeeUtil.new employees: [ce_employee], employer_profile: employer_profile_salon
        ee = employee.roster_employees.pop
        ee.inject({}) { |memo, (k, v)| memo[k.to_sym] = v; memo }
      }
    end

    it 'sorts employees' do
      sby = Util::EmployeeUtil.new(employer_profile: FactoryGirl.create(:employer_profile), status: 'all').employees_sorted_by
      expect(sby).to be_a_kind_of Mongoid::Criteria
      expect(sby.klass).to eq CensusEmployee
      expect(sby.options).to include(:sort)
      expect(sby.options[:sort]).to include('last_name', 'first_name', 'census_employee.last_name', 'census_employee.first_name')
    end

    it 'should return the count by enrollment status' do
      mobile_plan_year = Util::PlanYearUtil.new plan_year: employer_profile_cafe.show_plan_year
      benefit_group = Util::BenefitGroupUtil.new plan_year: mobile_plan_year.plan_year
      employee = Util::EmployeeUtil.new benefit_group: benefit_group
      expect(employee.count_by_enrollment_status).to eq [2, 0, 0]
    end

    it 'should return the basic individual' do
      individual_util = Api::V1::Mobile::Insured::InsuredPerson.new person: ce_employee
      individual = JSON.parse individual_util.basic_person 
      individual = individual.inject({}) { |memo, (k, v)| memo[k.to_sym] = v; memo }
      expect(individual).to include(:first_name, :middle_name, :last_name, :name_suffix, :date_of_birth, :ssn_masked,
                                    :gender)
      expect(individual[:date_of_birth]).to eq '1907-07-07'
      expect(individual[:first_name]).to_not be_nil
      expect(individual[:last_name]).to_not be_nil
      expect(individual[:middle_name]).to_not be_nil
      expect(individual[:name_suffix]).to_not be_nil
      expect(individual[:ssn_masked].match(/(\*\*\*-\*\*-\d{4}$)/)).to_not be_nil
      expect(individual[:gender]).to_not be_nil
    end

  end

end

