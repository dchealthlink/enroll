module Api
  module V1
    module Mobile
      class SecurityUtil < BaseUtil
        attr_accessor :employer_profile, :person

        def initialize args
          super args
          @employer_profile = EmployerProfile.find @params[:employer_profile_id] if @params[:employer_profile_id]
          @person = Person.find @params[:person_id] if @params[:person_id]
        end

        def authorize_employer_list
          return broker_role unless @params[:broker_agency_profile_id]
          @broker_agency_profile = BrokerAgencyProfile.find @params[:broker_agency_profile_id]
          @broker_agency_profile ? admin_or_staff : {status: 404}
        end

        def can_view_employer_details?
          can_view_employee_roster?
        end

        def can_view_employee_roster?
          is_hbx_staff? || is_employers_broker_staff? || is_employers_staff? || is_employers_broker?
        end

        def can_view_individual?
          is_hbx_staff? || is_the_person? || one_of_persons_brokers_staff? || one_of_persons_employers_staff? || is_persons_broker?
        end

        #
        # Private
        #
        private

        def is_employers_staff?
          active_employer_staff_roles.include? @employer_profile.id
        end

        def is_employers_broker?
          @user.person.broker_role &&
              @user.person.broker_role == @employer_profile.try(:active_broker_agency_account).try(:writing_agent)
        end

        def is_persons_broker?
          @user.person.broker_role &&
              @user.person.broker_role == @person.primary_family.try(:current_broker_agency).try(:broker_agency_profile).try(:primary_broker_role)
        end

        def is_hbx_staff?
          @user.has_hbx_staff_role?
        end

        def is_the_person?
          @user.person == @person
        end

        def one_of_persons_employers_staff?
          (active_employer_staff_roles & employer_profiles.map(&:id)).size > 0
        end

        def is_employers_broker_staff?
          broker_agency_staff_roles.include?(@employer_profile.try(:active_broker_agency_account).try(:broker_agency_profile_id))
        end

        def one_of_persons_brokers_staff?
          (broker_agency_staff_roles &
              employer_profiles.map { |ep| ep.try(:active_broker_agency_account).try(:broker_agency_profile_id) }).size > 0
        end

        def employer_profiles
          @employer_profiles ||= @person.active_employee_roles.map { |r| r.employer_profile }
        end

        def broker_role
          broker_role = @user.person.broker_role
          broker_role ? {broker_agency_profile: broker_role.broker_agency_profile, broker_role: broker_role, status: 200} : {status: 404}
        end

        def admin_or_staff
          is_hbx_staff? || broker_agency_staff_roles.include?(@params[:broker_agency_profile_id]) ?
              {broker_agency_profile: @broker_agency_profile, status: 200} : {status: 404}
        end

        def broker_agency_staff_roles
          @user.person.broker_agency_staff_roles.map(&:broker_agency_profile_id)
        end

        def active_employer_staff_roles
          @user.person.active_employer_staff_roles.map(&:employer_profile_id)
        end

      end
    end
  end
end