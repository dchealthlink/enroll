module Api
  module V1
    module Mobile::Util
      class EmployerUtil < Api::V1::Mobile::Base
        include UrlUtil

        def initialize args={}
          super args
          @plan_years = _select_current_and_upcoming (@employer_profile.try(:plan_years) || [])
        end

        def employers_and_broker_agency
          begin
            organizations = ->() {
              @organizations ||= @authorized.has_key?(:broker_role) ? Organization.by_broker_role(@authorized[:broker_role].id) :
                Organization.by_broker_agency_profile(@authorized[:broker_agency_profile]._id)
            }

            marshall_employer_summaries = ->() {
              return [] if @employer_profiles.blank?
              staff_by_employer_id = StaffUtil.new(employer_profiles: @employer_profiles).keyed_by_employer_id
              @employer_profiles.map do |er|
                _summary_details employer_profile: er,
                                 years: _select_current_and_upcoming(er.plan_years),
                                 staff: staff_by_employer_id[er.id],
                                 offices: er.organization.office_locations.select {|loc| loc.primary_or_branch?},
                                 include_details_url: true,
                                 include_enrollment_counts: true
              end
            }

            broker_response = ->(broker_name) {
              {
                broker_name: broker_name,
                broker_agency: @authorized[:broker_agency_profile].try(:legal_name),
                broker_agency_id: @authorized[:broker_agency_profile].id,
                broker_clients: marshall_employer_summaries.call
              }
            }
          end

          return if organizations.call.empty?
          @employer_profiles = organizations.call.map {|o| o.employer_profile}
          broker_name = @user.person.first_name if @user.person.broker_role
          broker_response[broker_name] if @authorized[:broker_agency_profile]
        end

        def employer_details
          details = _summary_details employer_profile: @employer_profile, years: @plan_years, include_plan_offerings: true
          details[:active_general_agency] = @employer_profile.active_general_agency_legal_name # Note: queries DB
          details
        end

        class << self

          def employer_profile_for_user user
            employer_staff_roles = user.person.try(:employer_staff_roles)
            unless employer_staff_roles.nil? || employer_staff_roles.empty?
              employer_profile_id = employer_staff_roles.detect {|x| x.is_active}.try(:employer_profile_id)
              EmployerProfile.find(employer_profile_id) if employer_profile_id
            end
          end

        end

        #
        # Private
        #
        private

        def _select_current_and_upcoming years
          years.select {|y| __is_current_or_upcoming? y.start_on}
        end

        def _summary_details employer_profile:, years: [], staff: nil, offices: nil, include_details_url: false, include_enrollment_counts: false, include_plan_offerings: false
          begin
            #
            # Alternative, faster way to calculate total_enrolled_count
            # Returns a list of number enrolled (actually enrolled, not waived) and waived
            # Check if the plan year is in renewal without triggering an additional query
            #
            count_by_enrollment_status = ->(mobile_plan_year) {
              employee = EmployeeUtil.new benefit_group: BenefitGroupUtil.new(plan_year: mobile_plan_year.plan_year)
              employee.count_by_enrollment_status
            }

            #
            # As a performance optimization, in the mobile summary API
            # (list of all employers for a broker) we only bother counting the subscribers
            # if the employer is currently in OE
            #
            add_count_to_plan_year_summary = ->(mobile_plan_year, plan_year_summary) {
              return unless include_enrollment_counts && mobile_plan_year.open_enrollment?
              enrolled, waived, terminated = count_by_enrollment_status[mobile_plan_year]
              plan_year_summary[:employees_enrolled] = enrolled
              plan_year_summary[:employees_waived] = waived
              plan_year_summary[:employees_terminated] = terminated
            }

            plan_year_summary = ->() {
              years.map do |year|
                mobile_plan_year = PlanYearUtil.new plan_year: year, as_of: TimeKeeper.date_of_record
                plan_year = include_plan_offerings ? mobile_plan_year.plan_year_details : mobile_plan_year.plan_year_summary
                add_count_to_plan_year_summary[mobile_plan_year, plan_year]
                plan_year
              end
            }

            summary_response = ->() {
              {
                employer_name: employer_profile.legal_name,
                employees_total: employer_profile.roster_size,
                plan_years: plan_year_summary.call,
                binder_payment_due: ''
              }
            }

            staff_response = ->(s) {
              {
                first: s.first_name,
                last: s.last_name,
                phone: s.work_phone.to_s,
                mobile: s.mobile_phone.to_s,
                emails: [s.work_email_or_best]
              }
            }

            office_response = ->(loc) {
              {
                first: loc.address.kind.capitalize,
                last: 'Office',
                phone: loc.phone.to_s,
                address_1: loc.address.address_1,
                address_2: loc.address.address_2,
                city: loc.address.city,
                state: loc.address.state,
                zip: loc.address.zip
              }
            }

            add_contact_info = ->(staff, offices) {
              staff.map {|s| staff_response[s]} + offices.map {|loc| office_response[loc]}
            }

            add_url = ->(summary) {
              summary[:employer_details_url] = employers_details_path employer_profile.id
              summary[:employee_roster_url] = employers_employees_path employer_profile.id
            }
          end

          summary = summary_response.call
          summary[:contact_info] = add_contact_info[staff || [], offices || []] if staff || offices
          add_url[summary] if include_details_url
          summary
        end

      end
    end
  end
end