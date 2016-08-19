

namespace :broker do
  desc "Import Database"

  task :employer => :environment do

    Organization.all.destroy_all if Organization.all.count > 0

    #print "\n^^^^ make brokers\n"
    (0..4).each_with_index do |org_index, index|
      organization = Organization.new(hbx_id: SecureRandom.hex(16), legal_name: Forgery('name').company_name + " " + "Agency", fein: (100000000 + index).to_s, is_active: 'true')
      #print "\nabout to save org: #{organization.legal_name}\n"
      organization.save(validate: false)

      broker_agency_profile_data = organization.build_broker_agency_profile(entity_kind: "s_corporation", market_kind: "both", languages_spoken: ["en"], working_hours: true, accept_new_clients: true, aasm_state: "is_approved")
      broker_agency_profile_data.save(validate: false)
    end

    #print "\n^^^^ make employers\n"
    Organization.all.collect(&:broker_agency_profile).each_with_index do |broker, index|
      (0..30).each do |employer_index|
        organization = Organization.new(hbx_id: SecureRandom.hex(16), legal_name: "Big " +  Forgery('name').company_name, fein: (200000000 + (100000 * index) + employer_index).to_s, is_active: 'true')
        organization.office_locations <<= office('primary')
        organization.office_locations <<= office('branch')

        #print "office locations: #{organization.office_locations.collect(&:address)}"
        #print "\nabout to save org: #{organization.legal_name}\n"
        organization.save(validate: false)
        #print "\n saved org with fein #{organization.fein}"
      
        employer_profile = organization.build_employer_profile(entity_kind: "s_corporation", aasm_state: "applicant", profile_source: "self_serve")
        employer_profile.save(validate: false)
        employer_profile.broker_agency_accounts.build(broker_agency_profile: broker, writing_agent_id: nil, start_on: Date.today).save  
        #employer_profile.hire_broker_agency(broker)
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
      (1..90).each do |index|
        employee = employer.census_employees.new(first_name: Forgery('name').first_name, last_name: Forgery('name').last_name, dob: Forgery('date').date, hired_on: Forgery('date').date, gender: Forgery('personal').gender, _type: "CensusEmployee",aasm_state: "eligible")
        employee.save(validate: false)
      end
      (0..1).each do |index|
        s = Person.new(first_name: Forgery('name').first_name, last_name: Forgery('name').last_name, dob: Forgery('date').date, gender: Forgery('personal').gender)
        s.emails << Email.new(:kind => 'work', :address => Forgery('email').address)
        s.phones << Phone.new(:kind => 'work', :area_code => '202', :number => '555-0001')
        s.phones << Phone.new(:kind => 'mobile', :area_code => '202', :number => '555-0002')
        s.employer_staff_roles << EmployerStaffRole.new(employer_profile_id: employer.id)
        s.save
      end 
    end
  end

  def office(kind)            
    a = Forgery('address')
    OfficeLocation.new(
          address: Address.new(kind: kind, address_1: a.street_address, city: 'Washington', state: 'DC',  zip: a.zip, country_name: 'USA'),
          phone: Phone.new(area_code: '202', number: '555-0001')
        )
  end

end


