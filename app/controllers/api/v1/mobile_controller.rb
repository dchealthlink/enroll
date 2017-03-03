module Api
  module V1
    class MobileController < ApplicationController
      include Api::V1::Mobile::RendererUtil
      Mobile = Api::V1::Mobile

      def broker
        execute {
          authorized = Mobile::SecurityUtil.new(user: current_user, params: params).authorize_employer_list
          if authorized[:status] == 200
            employer = Mobile::EmployerUtil.new authorized: authorized, user: current_user
            render_broker employer.employers_and_broker_agency
          else
            report_broker_error authorized[:status]
          end
        }
      end

      def employer_details
        execute {
          @security = Mobile::SecurityUtil.new user: current_user, params: params
          if @security.employer_profile
            render_employer @security.can_view_employer_details?, @security.employer_profile
          else
            report_employer_error
          end
        }
      end

      def my_employer_details
        execute {
          @employer_profile ||= Mobile::EmployerUtil.employer_profile_for_user current_user
          render_employer !@employer_profile.nil?, @employer_profile
        }
      end

      def employee_roster
        execute {
          @security = Mobile::SecurityUtil.new user: current_user, params: params
          if @security.employer_profile
            render_employees @security.can_view_employee_roster?, @security.employer_profile
          else
            report_employee_error
          end
        }
      end

      def my_employee_roster
        execute {
          @employer_profile ||= Mobile::EmployerUtil.employer_profile_for_user current_user
          render_employees !@employer_profile.nil?, @employer_profile
        }
      end

      def individuals
        execute {
          @security = Mobile::SecurityUtil.new(user: current_user, params: params)
          render_individual @security.can_view_individual?, @security.person
        }
      end

      def individual
        execute { render_individual true, current_user.person }
      end

      #
      # Private
      #
      private

      def render_individual can_view, person
        can_view ? render_individual_details(person) : report_individual_error
      end

      def render_employer can_view, employer_profile
        if can_view
          employer = Mobile::EmployerUtil.new employer_profile: employer_profile, report_date: params[:report_date]
          render_employer_details employer.employer_details
        else
          report_employer_error
        end
      end

      def render_employees can_view, employer_profile
        if can_view
          employees = Mobile::EmployeeUtil.new(employer_profile: employer_profile,
                                               employee_name: params[:employee_name],
                                               status: params[:status]).employees_sorted_by
          employees ? render_employee_roster(employer_profile, employees) : report_employee_error
        else
          report_employee_error
        end
      end

      def execute
        begin
          yield
        rescue Exception => e
          logger.error "Exception caught in employer_details: #{e.message}"
          e.backtrace.each { |line| logger.error line }
          message = ([:development, :test].include?(Rails.env.to_sym)) ? [e.message] + e.backtrace : e.message
          render json: {error: message}, :status => :internal_server_error
        end
      end

    end
  end
end