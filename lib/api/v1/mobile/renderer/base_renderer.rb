module Api
  module V1
    module Mobile::Renderer
      module BaseRenderer

        def report_error message, controller, status=:not_found
          controller.render json: {error: message}, status: status
        end

        def execute proc, controller, error=nil
          begin
            proc.call
          rescue StandardError => e
            Rails.logger.error "Exception: #{e.message}"
            report_error (error ? error : env_specific_error(e)), controller
          end
        end

        def env_specific_error e
          ([:development, :test].include? (Rails.env.to_sym)) ? [e.message] + e.backtrace : e.message
        end

      end

      BaseRenderer.module_eval do
        module_function :execute
        module_function :report_error
        module_function :env_specific_error
      end
    end
  end
end