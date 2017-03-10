module Api
  module V1
    module Mobile::Util
      class SecurityUtil < Api::V1::Mobile::Base
        attr_accessor :employer_profile, :person

        def initialize args
          super args
          @employer_profile = EmployerProfile.find @params[:employer_profile_id] if @params[:employer_profile_id]
          @person = Person.find @params[:person_id] if @params[:person_id]
        end

        def authorize_employer_list
          return _broker_role unless @params[:broker_agency_profile_id]
          @broker_agency_profile = BrokerAgencyProfile.find @params[:broker_agency_profile_id]
          @broker_agency_profile ? _admin_or_staff : {status: 404}
        end

        def can_view_employer_details?
          can_view_employee_roster?
        end

        def can_view_employee_roster?
          _is_hbx_staff? || _is_employers_broker_staff? || _is_employers_staff? || _is_employers_broker?
        end

        def can_view_insured?
          _is_hbx_staff? || _is_the_person? || _one_of_persons_brokers_staff? || _one_of_persons_employers_staff? || _is_persons_broker?
        end

        #
        # Private
        #
        private

        def _is_employers_staff?
          _active_employer_staff_roles.include? @employer_profile.id
        end

        def _is_employers_broker?
          @user.person.broker_role &&
              @user.person.broker_role == @employer_profile.try(:active_broker_agency_account).try(:writing_agent)
        end

        def _is_persons_broker?
          @user.person.broker_role &&
              @user.person.broker_role == @person.primary_family.try(:current_broker_agency).try(:broker_agency_profile).try(:primary_broker_role)
        end

        def _is_hbx_staff?
          @user.has_hbx_staff_role?
        end

        def _is_the_person?
          @user.person == @person
        end

        def _one_of_persons_employers_staff?
          (_active_employer_staff_roles & _employer_profiles.map(&:id)).size > 0
        end

        def _is_employers_broker_staff?
          _broker_agency_staff_roles.include?(@employer_profile.try(:active_broker_agency_account).try(:broker_agency_profile_id))
        end

        def _one_of_persons_brokers_staff?
          (_broker_agency_staff_roles &
              _employer_profiles.map { |ep| ep.try(:active_broker_agency_account).try(:broker_agency_profile_id) }).size > 0
        end

        def _employer_profiles
          @employer_profiles ||= @person.active_employee_roles.map { |r| r.employer_profile }
        end

        def _broker_role
          broker_role = @user.person.broker_role
          broker_role ? {broker_agency_profile: broker_role.broker_agency_profile, broker_role: broker_role, status: 200} : {status: 404}
        end

        def _admin_or_staff
          _is_hbx_staff? || _broker_agency_staff_roles.include?(@params[:broker_agency_profile_id]) ?
              {broker_agency_profile: @broker_agency_profile, status: 200} : {status: 404}
        end

        def _broker_agency_staff_roles
          @user.person.broker_agency_staff_roles.map(&:broker_agency_profile_id)
        end

        def _active_employer_staff_roles
          @user.person.active_employer_staff_roles.map(&:employer_profile_id)
        end

      end
    end
  end
end