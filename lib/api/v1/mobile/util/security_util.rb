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
          begin
            broker_role = ->() {
              broker_role = @user.person.broker_role
              broker_role ? {broker_agency_profile: broker_role.broker_agency_profile, broker_role: broker_role, status: 200} : {status: 404}
            }

            admin_or_staff = ->() {
              _is_hbx_staff? || _broker_agency_staff_roles.include?(@params[:broker_agency_profile_id]) ?
                {broker_agency_profile: @broker_agency_profile, status: 200} : {status: 404}
            }
          end

          return broker_role.call unless @params[:broker_agency_profile_id]
          @broker_agency_profile = BrokerAgencyProfile.find @params[:broker_agency_profile_id]
          @broker_agency_profile ? admin_or_staff.call : {status: 404}
        end

        def can_view_employer_details?
          can_view_employee_roster?
        end

        def can_view_employee_roster?
          begin
            is_employers_broker_staff = ->() {
              _broker_agency_staff_roles.include?(_broker_agency_profile_id(@employer_profile))
            }

            is_employers_staff = ->() { _active_employer_staff_roles.include? @employer_profile.id }

            is_employers_broker = ->() {
              @user.person.broker_role && @user.person.broker_role == _writing_agent(@employer_profile)
            }
          end

          _is_hbx_staff? || is_employers_broker_staff.call || is_employers_staff.call || is_employers_broker.call
        end

        def can_view_insured?
          begin
            is_persons_broker = ->() {
              @user.person.broker_role && @user.person.broker_role == _writing_agent(@employer_profile)
            }

            is_the_person = ->() { @user.person == @person }

            employer_profiles = ->() {
              @employer_profiles ||= @person.active_employee_roles.map { |r| r.employer_profile }
            }

            one_of_persons_brokers_staff = ->() {
              !(_broker_agency_staff_roles &
                employer_profiles.call.map { |ep| _broker_agency_profile_id(ep) }).empty?
            }

            one_of_persons_employers_staff = ->() {
              !(_active_employer_staff_roles & employer_profiles.call.map(&:id)).empty?
            }
          end

          _is_hbx_staff? || is_the_person.call || one_of_persons_brokers_staff.call ||
            one_of_persons_employers_staff.call || is_persons_broker.call
        end

        #
        # Private
        #
        private

        def _broker_agency_profile_id employer_profile
          employer_profile.try(:active_broker_agency_account).try(:broker_agency_profile_id)
        end

        def _writing_agent employer_profile
          employer_profile.try(:active_broker_agency_account).try(:writing_agent)
        end

        def _is_hbx_staff?
          @user.has_hbx_staff_role?
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