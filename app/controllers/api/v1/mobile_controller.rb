module Api
  module V1
    class MobileController < ActionController::Base
      include Api::V1::Mobile::Renderer::RidpRenderer
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
        _execute { Mobile::Renderer::BrokerRenderer::render_details current_user, params, self }
      end

      #
      # /employers/:employer_profile_id/details
      #
      def employer_details
        _execute { Mobile::Renderer::EmployerRenderer::render_details current_user, params, self }
      end

      #
      # /employer/details
      #
      def my_employer_details
        _execute { Mobile::Renderer::EmployerRenderer::render_my_details current_user, params, self }
      end

      #
      # /employers/:employer_profile_id/employees
      #
      def employee_roster
        _execute { Mobile::Renderer::EmployeeRenderer::render_details current_user, params, self }
      end

      #
      # /employer/employees
      #
      def my_employee_roster
        _execute { Mobile::Renderer::EmployeeRenderer::render_my_details current_user, params, self }
      end

      #
      # /insured/:person_id
      #
      def insured_person
        _execute { Mobile::Renderer::IndividualRenderer::render_details current_user, params, self }
      end

      #
      # /insured
      #
      def insured
        _execute { Mobile::Renderer::IndividualRenderer::render_my_details current_user, self }
      end

      #
      # /services_rates
      #
      def services_rates
        _execute { Mobile::Renderer::ServiceRenderer::render_details params, self }
      end

      #
      # /plans
      #
      def plans
        _execute { Mobile::Renderer::PlanRenderer::render_details params, self }
      end

      #
      # /verify_identity
      #
      def verify_identity
        _execute { Mobile::Renderer::RidpRenderer::render_questions request, self }
      end

      #
      # /verify_identity/answers
      #
      def verify_identity_answers
        _execute { Mobile::Renderer::RidpRenderer::render_answers request, self }
      end

      #
      # Private
      #
      private

      def _execute
        begin
          yield
        rescue StandardError => e
          render_env_specific_error = ->(e) {
            ([:development, :test].include? (Rails.env.to_sym)) ? [e.message] + e.backtrace : e.message
          }

          logger.error "Exception: #{e.message}"
          e.backtrace.each { |line| logger.error line }
          render json: {error: render_env_specific_error[e]}, :status => :internal_server_error
        end
      end

    end
  end
end