module Api
  module V1
    module Mobile::Renderer
      module BaseRenderer

        # Responds with an error.
        def report_error message, controller, status=:not_found
          controller.render json: message, status: status
        end

        # Returns a hash of the request payload.
        def payload_body request
          JSON.parse(request.body.read).with_indifferent_access
        end

        #
        # Wraps the RIDP renderers.
        #
        def execute proc, controller, error=nil
          begin
            proc.call
          rescue Mobile::Error::RIDPException => e
            Rails.logger.error "Exception: #{[e.message] + [e.backtrace]}"
            report_error env_specific_error(e), controller, e.code
          rescue StandardError => e
            Rails.logger.error "Exception: #{[e.message] + [e.backtrace]}"
            report_error env_specific_error(e, error), controller
          end
        end

        # Show more error details in the lower environments.
        def env_specific_error e, error=nil
          ([:development, :test].include? Rails.env.to_sym) ? [e.message, error].compact + e.backtrace : error || e.message
        end
      end

      BaseRenderer.module_eval do
        module_function :execute
        module_function :report_error
        module_function :payload_body
        module_function :env_specific_error
      end
    end
  end
end