require "rails_helper"
require 'lib/api/v1/support/mobile_employer_data'

RSpec.describe Api::V1::Mobile::Plan, dbclean: :after_each do
  include_context 'employer_data'
  Mobile = Api::V1::Mobile

  let!(:plan) {
    plan = FactoryGirl.create :active_individual_health_plan
    plan.deductible = '$5000'
    plan.family_deductible = '$5000 per person | $10000 per group'
    plan.save!
  }

  let!(:another_plan) {
    plan = FactoryGirl.create :active_individual_health_plan
    plan.deductible = '$5000'
    plan.family_deductible = '$5000 per person | $10000 per group'
    plan.save!
  }

  context 'Available Plans' do

    it 'should return a list of available plans' do
      plan = Mobile::Plan.new coverage_kind: 'health', active_year: '2017', ages: '21', csr_kind: 'csr_100'
      allow(Plan).to receive(:individual_plans).and_return(Plan.where(market: 'individual'))
      plans = JSON.parse plan.all_available_plans

      expect(plans).to be_a_kind_of Array
      plan = plans.last
      expect(plan).to include('id', 'active_year', 'coverage_kind', 'dc_in_network', 'dental_level', 'is_active',
                              'market', 'is_standard_plan', 'metal_level', 'maximum_age', 'minimum_age', 'name',
                              'nationwide', 'plan_type', 'provider', 'cost', 'hios', 'links')
      expect(plan['hios']).to include('id', 'base_id')
      expect(plan['cost']).to include('deductible', 'deductible_text', 'monthly_premium')
      expect(plan['links']).to include('summary_of_benefits', 'provider_directory', 'rx_formulary',
                                       'carrier_logo', 'services_rates')
      expect(plan['coverage_kind']).to eq 'health'
      expect(plan['links']['carrier_logo']).to eq '/assets/logo/carrier/uhic.jpg'
      expect(plan['links']['services_rates']).to eq "/api/v1/mobile/services_rates?hios_id=#{plan['hios']['id']}&active_year=#{plan['active_year']}&coverage_kind=#{plan['coverage_kind']}"
      expect(plan['active_year']).to eq '2017'
    end

    it 'should return the per person deductible when there is a single member' do
      plan = Mobile::Plan.new coverage_kind: 'health', active_year: '2017', ages: '21', csr_kind: 'csr_100'
      allow(Plan).to receive(:individual_plans).and_return(Plan.where(market: 'individual'))
      plans = JSON.parse plan.all_available_plans

      expect(plans).to be_a_kind_of Array
      plan = plans.last

      expect(plan['cost']['deductible']).to eq 5000
      expect(plan['cost']['deductible_text']).to eq '$5000 per person | $10000 per group'
    end

    it 'should return the family deductible when there are multiple members' do
      plan = Mobile::Plan.new coverage_kind: 'health', active_year: '2017', ages: '21,22', csr_kind: 'csr_100'
      allow(Plan).to receive(:individual_plans).and_return(Plan.where(market: 'individual'))
      plans = JSON.parse plan.all_available_plans

      expect(plans).to be_a_kind_of Array
      plan = plans.last

      expect(plan['cost']['deductible']).to eq 10000
      expect(plan['cost']['deductible_text']).to eq '$5000 per person | $10000 per group'
    end

    it 'should return the monthly premium for 1 person' do
      Caches::PlanDetails.load_record_cache!
      plan = Mobile::Plan.new coverage_kind: 'health', active_year: '2017', ages: '21', csr_kind: 'csr_100'
      allow(Plan).to receive(:individual_plans).and_return(Plan.where(market: 'individual'))
      plans = JSON.parse plan.all_available_plans
      plan = plans.last
      expect(plan['cost']['monthly_premium']).to eq 210.21
    end

    it 'should return the monthly premium for 2 people' do
      Caches::PlanDetails.load_record_cache!
      plan = Mobile::Plan.new coverage_kind: 'health', active_year: '2017', ages: '21,22', csr_kind: 'csr_100'
      allow(Plan).to receive(:individual_plans).and_return(Plan.where(market: 'individual'))
      plans = JSON.parse plan.all_available_plans
      plan = plans.last
      expect(plan['cost']['monthly_premium']).to eq 430.43
    end

  end
end