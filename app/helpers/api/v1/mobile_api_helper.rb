module Api::V1::MobileApiHelper

  def render_employee_contacts_json(staff, offices)
      #TODO null handling
      staff.map do |s| 
                { 
                  first: s.first_name, last: s.last_name, phone: s.work_phone.to_s,
                  mobile: s.mobile_phone.to_s, emails: [s.work_email_or_best]
                }
             end + offices.map do |loc|
                {
                  first: loc.address.kind.capitalize, last: "Office", phone: loc.phone.to_s, 
                  address_1: loc.address.address_1, address_2: loc.address.address_2,
                  city: loc.address.city, state: loc.address.state, zip: loc.address.zip
                }
             end
  end

  def render_employer_summary_json(employer_profile: nil, year: nil, num_enrolled: nil, 
                                        num_waived: nil, staff: nil, offices: nil, 
                                        include_details_url: false)
    renewals_offset_in_months = Settings.aca.shop_market.renewal_application.earliest_start_prior_to_effective_on.months

    summary = { 
      employer_name: employer_profile.legal_name,
      employees_total: employer_profile.roster_size,   
      employees_enrolled:             num_enrolled,  
      employees_waived:               num_waived,
      open_enrollment_begins:         year ? year.open_enrollment_start_on                 : nil,
      open_enrollment_ends:           year ? year.open_enrollment_end_on                   : nil,
      plan_year_begins:               year ? year.start_on                                 : nil,
      renewal_in_progress:            year ? year.is_renewing?                             : nil,
      renewal_application_available:  year ? (year.start_on >> renewals_offset_in_months)  : nil,
      renewal_application_due:        year ? year.due_date_for_publish                     : nil,
      binder_payment_due:             "",
      minimum_participation_required: year ? year.minimum_enrolled_count                   : nil,
    }
    if staff or offices then
      summary[:contact_info] = render_employee_contacts_json(staff || [], offices || [])
    end
    if include_details_url then
      summary[:employer_details_url] = Rails.application.routes.url_helpers.api_v1_mobile_api_employer_details_path(employer_profile.id)
      summary[:employee_roster_url] = Rails.application.routes.url_helpers.api_v1_mobile_api_employee_roster_path(employer_profile.id)
    end
    summary
  end

  def render_employer_details_json(employer_profile: nil, year: nil, num_enrolled: nil, 
                                        num_waived: nil, total_premium: nil, 
                                        employer_contribution: nil, employee_contribution: nil)
    details = render_employer_summary_json(employer_profile: employer_profile, year: year, 
                                           num_enrolled: num_enrolled, num_waived: num_waived)
    details[:total_premium] = total_premium
    details[:employer_contribution] = employer_contribution
    details[:employee_contribution] = employee_contribution
    details[:active_general_agency] = employer_profile.active_general_agency_legal_name # Note: queries DB

    #TODO next release
    #details[:reference_plan] = 
    #details[:offering_type] = 
    #details[:new_hire_rule] = 
    #details[:contribution_levels] = 
     details
  end

  def get_benefit_group_assignments_for_plan_year(plan_year)
      #check if the plan year is in renewal without triggering an additional query
      in_renewal = PlanYear::RENEWING_PUBLISHED_STATE.include?(plan_year.aasm_state)

      benefit_group_ids = plan_year.benefit_groups.map(&:id)
      employees = CensusMember.where({
        "benefit_group_assignments.benefit_group_id" => { "$in" => benefit_group_ids },
        :aasm_state => { '$in' => ['eligible', 'employee_role_linked']}
        })
      employees.map do |ee|
            ee.benefit_group_assignments.select do |bga| 
                benefit_group_ids.include?(bga.benefit_group_id) && (in_renewal || bga.is_active)
            end
      end.flatten
  end

  # alternative, faster way to calcuate total_enrolled_count 
  # returns a list of number enrolled (actually enrolled, not waived) and waived
  def count_enrolled_and_waived_employees(plan_year)  
    if plan_year && plan_year.employer_profile.census_employees.count < 100 then
      assignments = get_benefit_group_assignments_for_plan_year(plan_year)
      count_shop_and_health_enrolled_and_waived_by_benefit_group_assignments(assignments)
    end 
  end
  
  # as a performance optimization, in the mobile summary API (list of all employers for a broker)
  # we only bother counting the subscribers if the employer is currently in OE
  def count_enrolled_and_waived_employees_if_in_open_enrollment(plan_year, as_of)
    if plan_year && as_of && 
       plan_year.open_enrollment_start_on && plan_year.open_enrollment_end_on &&
       plan_year.open_enrollment_contains?(as_of) then
        count_enrolled_and_waived_employees(plan_year) 
    else
        nil
    end
  end

  def marshall_employer_summaries_json(employer_profiles, report_date) 
    return [] if employer_profiles.blank?
    all_staff_by_employer_id = staff_for_employers_including_pending(employer_profiles.map(&:id))
    employer_profiles.map do |er|  
        #print "$$$$ in map with #{er} \n\n" 
        offices = er.organization.office_locations.select { |loc| loc.primary_or_branch? }
        staff = all_staff_by_employer_id[er.id]
        plan_year = er.show_plan_year
        enrolled, waived = count_enrolled_and_waived_employees_if_in_open_enrollment(plan_year, TimeKeeper.date_of_record) 
        render_employer_summary_json(employer_profile: er, year: plan_year, 
                                     num_enrolled: enrolled, num_waived: waived, 
                                     staff: staff, offices: offices, include_details_url: true) 
    end  
  end

  def marshall_employer_details_json(employer_profile, report_date)
    plan_year = employer_profile.show_plan_year
    if plan_year then
      enrollments = employer_profile.enrollments_for_billing(report_date)
      premium_amt_total   = enrollments.map(&:total_premium).sum 
      employee_cost_total = enrollments.map(&:total_employee_cost).sum
      employer_contribution_total = enrollments.map(&:total_employer_contribution).sum
      enrolled, waived = count_enrolled_and_waived_employees(plan_year)
      
      render_employer_details_json(employer_profile: employer_profile, 
                                   year: plan_year,  
                                   num_enrolled: enrolled, 
                                   num_waived: waived, 
                                   total_premium: premium_amt_total, 
                                   employer_contribution: employer_contribution_total, 
                                   employee_contribution: employee_cost_total)
    else
      render_employer_details_json(employer_profile: employer_profile)
    end
  end

  # returns a hash of arrays of staff members, keyed by employer id
  def staff_for_employers_including_pending(employer_profile_ids)
      
      staff = Person.where(:employer_staff_roles => {
        '$elemMatch' => {
            employer_profile_id: {  "$in": employer_profile_ids },
            :aasm_state.ne => :is_closed
        }
        })

      result = {}
      staff.each do |s| 
        s.employer_staff_roles.each do |r|
          if (!result[r.employer_profile_id]) then 
            result[r.employer_profile_id] = [] 
          end
          result[r.employer_profile_id] <<= s  
        end
      end
      result.compact
  end


  def benefit_group_ids_of_enrollments_in_status(enrollments, status_list)
    enrollments.select do |enrollment| 
      status_list.include? (enrollment[:aasm_state]) 
    end.map { |e| e[:benefit_group_assignment_id] }
  end

  # A faster way of counting employees who are enrolled (not waived) 
  # where enrolled + waived = counting towards SHOP minimum healthcare participation
  # We first do the query to find families with appropriate enrollments,
  # then check again inside the map/reduce to get only those enrollments.
  # This avoids undercounting, e.g. two family members working for the same employer. 
  #
  def count_shop_and_health_enrolled_and_waived_by_benefit_group_assignments(benefit_group_assignments = [])
    enrolled_or_renewal = HbxEnrollment::ENROLLED_STATUSES + HbxEnrollment::RENEWAL_STATUSES
    waived = HbxEnrollment::WAIVED_STATUSES

    return [] if benefit_group_assignments.blank?
    id_list = benefit_group_assignments.map(&:id) #.uniq

    db = Mongoid::Clients.default

    families = db[:families].find(
      {:"households.hbx_enrollments" => 
        { "$elemMatch" => 
          {
            "benefit_group_assignment_id" => { "$in" => id_list }, 
            :aasm_state => { "$in" => enrolled_or_renewal + waived }, 
            :kind => "employer_sponsored", 
            :coverage_kind => "health",
            :is_active => true #???  
          }
        }
      })

    all_enrollments =  families.map { |f| f[:households].map {|h| h[:hbx_enrollments]} }.flatten.compact
    relevant_enrollments = all_enrollments.select do |enrollment|
      enrollment[:kind] == "employer_sponsored" &&
      enrollment[:coverage_kind] == "health" &&
      enrollment[:is_active]
    end

    enrolled_ids = benefit_group_ids_of_enrollments_in_status(relevant_enrollments, enrolled_or_renewal)
    waived_ids = benefit_group_ids_of_enrollments_in_status(relevant_enrollments, waived)

    #return count of enrolled, count of waived -- only including those originally asked for
    [enrolled_ids, waived_ids].map { |found_ids| (found_ids & id_list).count }
  end

  def employees_by(employer_profile, by_employee_name = nil, by_status = 'active')
    census_employees = case by_status
                   when 'terminated'
                     employer_profile.census_employees.terminated
                   when 'all'
                     employer_profile.census_employees
                   else
                     employer_profile.census_employees.active
                   end.sorted
    by_employee_name ? census_employees.employee_name(by_employee_name) : census_employees
  end

  def status_label_for(enrollment_status)
    {
      'Renewing' => HbxEnrollment::RENEWAL_STATUSES,
      'Terminated' => HbxEnrollment::TERMINATED_STATUSES,
      'Enrolled' => HbxEnrollment::ENROLLED_STATUSES,
      'Waived' => HbxEnrollment::WAIVED_STATUSES
    }.each do |label, enrollment_statuses|
        return label if enrollment_statuses.include?(enrollment_status.to_s)
    end
  end

  ROSTER_ENROLLMENT_PLAN_FIELDS_TO_RENDER = [:plan_type, :deductible, :family_deductible, :provider_directory_url, :rx_formulary_url]  
  def render_roster_employee(census_employee, has_renewal)
    assignments = { active: census_employee.active_benefit_group_assignment }
    assignments[:renewal] = census_employee.renewal_benefit_group_assignment if has_renewal
    enrollments = {}
    assignments.keys.each do |period_type|
      assignment = assignments[period_type]
      enrollments[period_type] = {}
      %W(health dental).each do |coverage_kind|
          enrollment = assignment.hbx_enrollments.detect { |e| e.coverage_kind == coverage_kind } if assignment
          rendered_enrollment = if enrollment then
            {
              status: status_label_for(enrollment.aasm_state),
              employer_contribution: enrollment.total_employer_contribution,
              employee_cost: enrollment.total_employee_cost,
              total_premium: enrollment.total_premium,
              plan_name: enrollment.plan.try(:name),
              metal_level:  enrollment.plan.try(coverage_kind == "health" ? :metal_level : :dental_level)
            } 
          else 
            {
              status: 'Not Enrolled'
            }
          end
          if enrollment && enrollment.plan 
            ROSTER_ENROLLMENT_PLAN_FIELDS_TO_RENDER.each do |field|
              value = enrollment.plan.try(field)
              rendered_enrollment[field] = value if value
            end
          end
          enrollments[period_type][coverage_kind] = rendered_enrollment
      end
    end

    {
      id: census_employee.id,
      first_name:   census_employee.first_name,
      middle_name:  census_employee.middle_name,
      last_name:    census_employee.last_name,
      name_suffix:  census_employee.name_sfx,
      enrollments:  enrollments
    }
  end

  def render_roster_employees(employees, has_renewal)
    employees.compact.map do |ee| 
      render_roster_employee(ee, has_renewal) 
    end
  end

   def fetch_employers_and_broker_agency(user, submitted_id)
        #print ("$$$$ fetch_employers_and_broker_agency(#{user}, #{submitted_id})\n")
         broker_role = user.person.broker_role
         broker_name = user.person.first_name if broker_role 

        if submitted_id && (user.has_broker_agency_staff_role? || user.has_hbx_staff_role?)
          broker_agency_profile = BrokerAgencyProfile.find(submitted_id)
          employer_query = Organization.by_broker_agency_profile(broker_agency_profile._id) if broker_agency_profile
#TODO fix security hole
#@broker_agency_profile = current_user.person.broker_agency_staff_roles.first.broker_agency_profile

        else
          if broker_role
            broker_agency_profile = broker_role.broker_agency_profile 
            employer_query = Organization.by_broker_role(broker_role.id) 
          end
        end
        employer_profiles = (employer_query || []).map {|o| o.employer_profile}  
        [employer_profiles, broker_agency_profile, broker_name] if employer_query
      end

end


