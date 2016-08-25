module Employers::EmployerHelper
  def address_kind
    @family.try(:census_employee).try(:address).try(:kind) || 'home'
  end

  def enrollment_state(census_employee=nil)
    humanize_enrollment_states(census_employee.active_benefit_group_assignment)
  end

  def renewal_enrollment_state(census_employee=nil)
    humanize_enrollment_states(census_employee.renewal_benefit_group_assignment)
  end

  def humanize_enrollment_states(benefit_group_assignment)
    enrollment_states = []

    if benefit_group_assignment
      enrollments = benefit_group_assignment.hbx_enrollments

      %W(health dental).each do |coverage_kind|
        if coverage = enrollments.detect{|enrollment| enrollment.coverage_kind == coverage_kind}
          enrollment_states << "#{benefit_group_assignment_status(coverage.aasm_state)} (#{coverage_kind})"
        end
      end
      enrollment_states << '' if enrollment_states.compact.empty?
    end

    "#{enrollment_states.compact.join('<br/> ').titleize.to_s}".html_safe
    
  end

  def benefit_group_assignment_status(enrollment_status)
    assignment_mapping = {
      'coverage_renewing' => HbxEnrollment::RENEWAL_STATUSES,
      'coverage_terminated' => HbxEnrollment::TERMINATED_STATUSES,
      'coverage_selected' => HbxEnrollment::ENROLLED_STATUSES,
      'coverage_waived' => HbxEnrollment::WAIVED_STATUSES
    }

    assignment_mapping.each do |bgsm_state, enrollment_statuses|
      if enrollment_statuses.include?(enrollment_status.to_s)
        return bgsm_state
      end
    end
  end

  def render_plan_offerings(benefit_group)

    assignment_mapping.each do |bgsm_state, enrollment_statuses|
      if enrollment_statuses.include?(enrollment_status.to_s)
        return bgsm_state
      end
    end
  end



  def self.render_employee_contact_json(first: "", last: "", phone: "", mobile: "", emails: [], address_1: "", address_2: "", 
                      city: "", state: "", zip: "")
    OpenStruct.new({ :first => first, :last => last, :phone => phone, :mobile => mobile,
            :emails => emails, :address_1 => address_1, :address_2 => address_2, :city => city,
            :state => state, :zip => zip }) 
  end

  def self.render_employee_contacts_json(staff, offices)
      #TODO null handling
      staff.map do |s| 
             self.render_employee_contact_json(first: s.first_name, last: s.last_name, phone: s.work_phone.to_s,
                            mobile: s.mobile_phone.to_s, emails: [s.work_email_or_best])
             end + offices.map do |loc|
               self.render_employee_contact_json(first: loc.address.kind.capitalize, last: "Office", phone: loc.phone.to_s,
                 address_1: loc.address.address_1, address_2: loc.address.address_2, city: loc.address.city,
                 state: loc.address.state, zip: loc.address.zip)
             end
  end

  
  def invoice_formated_date(date)
    date.strftime("%m/%d/%Y")
  end

  def invoice_coverage_date(date)
    "#{date.next_month.beginning_of_month.strftime('%b %Y')}" rescue nil
  end

  def coverage_kind(census_employee=nil)
    return "" if census_employee.blank? || census_employee.employee_role.blank?
    enrolled = census_employee.active_benefit_group_assignment.try(:aasm_state)
    if enrolled.present? && enrolled != "initialized"
      begin
        #kind = census_employee.employee_role.person.primary_family.enrolled_including_waived_hbx_enrollments.map(&:plan).map(&:coverage_kind).sort.reverse.uniq.join(", ")
        kind = census_employee.employee_role.person.primary_family.enrolled_including_waived_hbx_enrollments.map(&:plan).map(&:coverage_kind).sort.reverse.join(", ")
      rescue
        kind = ""
      end
    else
      kind = ""
    end
    return kind.titleize
  end

  def render_plan_offerings(benefit_group, coverage_type)
    reference_plan = benefit_group.reference_plan
    if coverage_type == ".dental" && benefit_group.dental_plan_option_kind == "single_plan"
      plan_count = benefit_group.elected_dental_plan_ids.count
      "#{plan_count} Plans"
    elsif coverage_type == ".dental" && benefit_group.dental_plan_option_kind == "single_carrier"
      plan_count = Plan.shop_dental_by_active_year(reference_plan.active_year).by_carrier_profile(reference_plan.carrier_profile).count
      "All #{reference_plan.carrier_profile.legal_name} Plans (#{plan_count})"
    else
      return "1 Plan Only" if benefit_group.single_plan_type?
      if benefit_group.plan_option_kind == "single_carrier"
        plan_count = Plan.shop_health_by_active_year(reference_plan.active_year).by_carrier_profile(reference_plan.carrier_profile).count
        "All #{reference_plan.carrier_profile.legal_name} Plans (#{plan_count})"
      else
        plan_count = Plan.shop_health_by_active_year(reference_plan.active_year).by_health_metal_levels([reference_plan.metal_level]).count
        "#{reference_plan.metal_level.titleize} Plans (#{plan_count})"
      end
    end
  end

  def get_benefit_groups_for_census_employee
    plan_years = @employer_profile.plan_years.select{|py| (PlanYear::PUBLISHED + ['draft']).include?(py.aasm_state) && py.end_on > TimeKeeper.date_of_record}
    benefit_groups = plan_years.flat_map(&:benefit_groups)
    renewing_benefit_groups = @employer_profile.renewing_plan_year.benefit_groups if @employer_profile.renewing_plan_year
    return benefit_groups, (renewing_benefit_groups || [])
  end

  def self.render_employer_summary_json(employer_profile, year, staff, offices, subscriber_count, renewals_offset_in_months)
    er = employer_profile
    { 
      employer_name: er.legal_name,
      employees_total: er.roster_size,   
      employees_enrolled:             subscriber_count,  
      employees_waived:               year ? year.waived_count                             : nil,
      open_enrollment_begins:         year ? year.open_enrollment_start_on                 : nil,
      open_enrollment_ends:           year ? year.open_enrollment_end_on                   : nil,
      plan_year_begins:               year ? year.start_on                                 : nil,
      renewal_in_progress:            year ? year.is_renewing?                             : nil,
      renewal_application_available:  year ? (year.start_on >> renewals_offset_in_months)  : nil,
      renewal_application_due:        year ? year.due_date_for_publish                     : nil,
      binder_payment_due:             "",
      minimum_participation_required: year ? year.minimum_enrolled_count                   : nil,
      contact_info:                   self.render_employee_contacts_json(staff, offices), 
      active_general_agency:          er.active_general_agency_legal_name 
    }
  end

  def self.employer_details(employer_profiles, all_staff_by_employer_id)
    renewals_offset_in_months = Settings.aca.shop_market.renewal_application.earliest_start_prior_to_effective_on.months
    @employer_details = employer_profiles.map do |er| 
    billing_plan_year, billing_report_date = er.billing_plan_year 
    subscribers_already_counted = {}
    if er.show_plan_year.nil? then
       subscriber_count = nil
    else 
       show_plan_year_enrollments = er.show_plan_year.hbx_enrollments_by_month(billing_report_date).compact
       subscriber_count = show_plan_year_enrollments.inject(0) do |subs, en|
      if (!subscribers_already_counted[en.subscriber.applicant_id]) then
         subscribers_already_counted[en.subscriber.applicant_id] = true
         subs += 1
         end
         print " >>>> Enrollment for: #{ en.subscriber.inspect } \n"
         subs 
      end
    end
    staff = all_staff_by_employer_id[er.id] || [] 
    offices = er.organization.office_locations.select { |loc| loc.primary_or_branch? }
    self.render_employer_summary_json(er, er.show_plan_year, staff, offices, subscriber_count, renewals_offset_in_months) 
    end   
  end

  

end
