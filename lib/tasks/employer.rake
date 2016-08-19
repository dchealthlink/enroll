namespace :broker do
  desc "Import Database"
  task :employer => :environment do
    Organization.all.destroy_all if Organization.all.count > 0
    (0..4).each_with_index do |org_index, index|
      organization = Organization.new(hbx_id: SecureRandom.hex(16), legal_name: Forgery('name').company_name + " " + "Agency", fein: SecureRandom.hex(4),is_active: 'true')
      organization.save(validate: false)

      broker_agency_profile_data = organization.build_broker_agency_profile(entity_kind: "s_corporation", market_kind: "both", languages_spoken: ["en"], working_hours: true, accept_new_clients: true, aasm_state: "is_approved")
      broker_agency_profile_data.save(validate: false)

    end

    Organization.all.collect(&:broker_agency_profile).each_with_index do |broker, index|
      (0..9).each do |employer_index|
        organization = Organization.new(hbx_id: SecureRandom.hex(16), legal_name: Forgery('name').company_name, fein: SecureRandom.hex(4),is_active: 'true')
        organization.save(validate: false)
      
        employer_profile = organization.build_employer_profile(entity_kind: "s_corporation", aasm_state: "applicant", profile_source: "self_serve")
        employer_profile.save(validate: false)
          employer_profile.broker_agency_accounts.build(broker_agency_profile: broker, writing_agent_id: nil, start_on: Date.today).save   
      end
    end
    

    employer_profiles = Organization.all.collect(&:employer_profile).compact
    
    employer_profiles.each_with_index do |employer, index|
      carrier_profile = employer.organization.build_carrier_profile
      carrier_profile.save(validate: false)

      level = %w(gold silver platinum bronze).shuffle.sample
      kind = %w(dental health).shuffle.sample 
      type = %w(pos hmo epo ppo).shuffle.sample 
      market = %w(individual shop).shuffle.sample 
      plan_option = %w(single_plan single_carrier metal_level).shuffle.sample 

      plan = Plan.new(active_year: "2014",market: market,coverage_kind: kind, metal_level: level, name: "Access PPO",minimum_age: 19,maximum_age: 66, is_active: true, plan_type: type,carrier_profile_id: carrier_profile.id)
      plan.save(validate: false)
      plan_year = employer.plan_years.build(start_on: Date.today.at_beginning_of_month,end_on: Date.today.end_of_month ,open_enrollment_start_on: Date.today,open_enrollment_end_on: Date.today-1.year)
      plan_year.save(validate: false)
      benefit_group = plan_year.benefit_groups.build(title: Forgery('name').industry,reference_plan_id: plan.id,plan_option_kind: plan_option,lowest_cost_plan_id: plan.id,highest_cost_plan_id: plan.id)
      benefit_group.save(validate: false)
      (1..20).each do |index|
        employee = employer.census_employees.new(first_name: Forgery('name').first_name, last_name: Forgery('name').last_name,dob: BrokerAgencyProfile.time_rand.to_date, hired_on: BrokerAgencyProfile.time_rand_for_hire.to_date,gender: Forgery('personal').gender, _type: "CensusEmployee",aasm_state: "eligible")
        employee.save(validate: false)
      end
    end
  end
end


