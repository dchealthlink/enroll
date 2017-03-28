module Api
  module V1
    class MobileController < ApplicationController
      include Api::V1::Mobile::Renderer::ServiceRenderer
      include Api::V1::Mobile::Renderer::PlanRenderer
      include Api::V1::Mobile::Renderer::IndividualRenderer
      include Api::V1::Mobile::Renderer::EmployeeRenderer
      include Api::V1::Mobile::Renderer::EmployerRenderer
      include Api::V1::Mobile::Renderer::BrokerRenderer
      Mobile = Api::V1::Mobile

      #
      # /broker
      #
      def broker
        _execute {
          authorized = Mobile::Util::SecurityUtil.new(user: current_user, params: params).authorize_employer_list
          if authorized[:status] == 200
            employer = Mobile::Util::EmployerUtil.new authorized: authorized, user: current_user
            Mobile::Renderer::BrokerRenderer::render_details employer.employers_and_broker_agency, self
          else
            Mobile::Renderer::BrokerRenderer::report_error authorized[:status], self
          end
        }
      end

      #
      # /employers/:employer_profile_id/details
      #
      def employer_details
        _execute {
          @security = Mobile::Util::SecurityUtil.new user: current_user, params: params
          if @security.employer_profile
            _render_employer @security.can_view_employer_details?, @security.employer_profile
          else
            Mobile::Renderer::EmployerRenderer::report_error self
          end
        }
      end

      #
      # /employer/details
      #
      def my_employer_details
        _execute {
          @employer_profile ||= Mobile::Util::EmployerUtil.employer_profile_for_user current_user
          _render_employer !@employer_profile.nil?, @employer_profile
        }
      end

      #
      # /employers/:employer_profile_id/employees
      #
      def employee_roster
        _execute {
          @security = Mobile::Util::SecurityUtil.new user: current_user, params: params
          @security.employer_profile ? _render_employees(@security.can_view_employee_roster?, @security.employer_profile) :
            Mobile::Renderer::EmployeeRenderer::report_error(self)
        }
      end

      #
      # /employer/employees
      #
      def my_employee_roster
        _execute {
          @employer_profile ||= Mobile::Util::EmployerUtil.employer_profile_for_user current_user
          _render_employees !@employer_profile.nil?, @employer_profile
        }
      end

      #
      # /insured/:person_id
      #
      def insured_person
        _execute {
          @security = Mobile::Util::SecurityUtil.new(user: current_user, params: params)
          _render_insured @security.can_view_insured?, @security.person
        }
      end

      #
      # /insured
      #
      def insured
        _execute { _render_insured true, current_user.person }
      end

      #
      # /services_rates
      #
      def services_rates
        _execute {
          hios_id, active_year, coverage_kind = params.values_at :hios_id, :active_year, :coverage_kind

          if hios_id && active_year && coverage_kind
            Mobile::Renderer::ServiceRenderer::render_details hios_id, active_year, coverage_kind, self
          else
            Mobile::Renderer::ServiceRenderer::report_error self
          end
        }
      end

      #
      # /plans
      #
      def plans
        _execute { Mobile::Renderer::PlanRenderer::render_details params, self }
      end

      #
      # Private
      #
      private

      def _render_insured can_view, person
        can_view ? Mobile::Renderer::IndividualRenderer::render_details(person, self) :
          Mobile::Renderer::IndividualRenderer::report_error(self)
      end

      def _render_employer can_view, employer_profile
        if can_view
          employer = Mobile::Util::EmployerUtil.new employer_profile: employer_profile, report_date: params[:report_date]
          Mobile::Renderer::EmployerRenderer::render_details employer.employer_details, self
        else
          Mobile::Renderer::EmployerRenderer::report_error self
        end
      end

      def _render_employees can_view, employer_profile
        if can_view
          employees = Mobile::Util::EmployeeUtil.new(employer_profile: employer_profile,
                                                     employee_name: params[:employee_name],
                                                     status: params[:status]).employees_sorted_by
          employees ? Mobile::Renderer::EmployeeRenderer::render_details(employer_profile, employees, self) :
            Mobile::Renderer::EmployeeRenderer::report_error(self)
        else
          Mobile::Renderer::EmployeeRenderer::report_error self
        end
      end

      def _execute
        begin
          yield
        rescue Exception => e
          logger.error "Exception: #{e.message}"
          e.backtrace.each { |line| logger.error line }
          message = ([:development, :test].include? (Rails.env.to_sym)) ? [e.message] + e.backtrace : e.message
          render json: {error: message}, :status => :internal_server_error
        end
      end

    end
  end
end