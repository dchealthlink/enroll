module Api
  module V1
    class MobileController < ActionController::Base
      include Api::V1::Mobile::Renderer::BaseRenderer
      Mobile = Api::V1::Mobile

      before_filter :_require_login, except: [:services_rates, :plans]

      #
      # /broker
      #
      def broker
        _execute {Mobile::Renderer::BrokerRenderer::render_details current_user, params, self}
      end

      #
      # /employers/:employer_profile_id/details
      #
      def employer_details
        _execute {Mobile::Renderer::EmployerRenderer::render_details current_user, params, self}
      end

      #
      # /employer/details
      #
      def my_employer_details
        _execute {Mobile::Renderer::EmployerRenderer::render_my_details current_user, params, self}
      end

      #
      # /employers/:employer_profile_id/employees
      #
      def employee_roster
        _execute {Mobile::Renderer::EmployeeRenderer::render_details current_user, params, self}
      end

      #
      # /employer/employees
      #
      def my_employee_roster
        _execute {Mobile::Renderer::EmployeeRenderer::render_my_details current_user, params, self}
      end

      #
      # /insured/:person_id
      #
      def insured_person
        _execute {Mobile::Renderer::InsuredRenderer::render_details current_user, params, self}
      end

      #
      # /insured
      #
      def insured
        _execute {Mobile::Renderer::InsuredRenderer::render_my_details current_user, self}
      end

      #
      # /services_rates
      #
      def services_rates
        _execute {Mobile::Renderer::ServiceRenderer::render_details params, self}
      end

      #
      # /plans
      #
      def plans
        _execute {Mobile::Renderer::PlanRenderer::render_details params, self}
      end

      #
      # /verify_identity
      #
      def verify_identity
        _execute {Mobile::Renderer::RidpRenderer::render_questions request, self}
      end

      #
      # /verify_identity/answers
      #
      def verify_identity_answers
        _execute {Mobile::Renderer::RidpRenderer::render_answers request, self}
      end

      #
      # /check_user_existence
      #
      def check_user_existence
        _execute {Mobile::Renderer::UserExistenceRenderer::render_details request, self}
      end

      #
      # Private
      #
      private

      def _execute
        begin
          yield
        rescue StandardError => e
          logger.error "Exception: #{e.message}"
          e.backtrace.each {|line| logger.error line}
          render json: {error: env_specific_error(e)}, :status => :internal_server_error
        end
      end

      def _require_login
        render json: {error: 'user not authenticated'} unless current_user
      end

    end
  end
end