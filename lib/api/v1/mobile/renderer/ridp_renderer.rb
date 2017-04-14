module Api
  module V1
    module Mobile::Renderer
      module RidpRenderer
        include BaseRenderer
        extend Api::V1::Mobile::Util::UrlUtil
        MESSAGE_SUFFIX = "not received or could not be processed"
        IDENTITY_VERIFICATION_QUESTIONS_ERROR = "valid identity verification questions were #{MESSAGE_SUFFIX}"
        IDENTITY_VERIFICATION_ANSWERS_ERROR = "valid identity verification response was #{MESSAGE_SUFFIX}"

        def render_questions request, controller
          begin
            render_response = ->() {
              controller.response.headers['Location'] = verify_identity_answers_path
              controller.render json: _ridp_verification_instance(request).build_question_response
            }
          end

          BaseRenderer::execute render_response, controller, IDENTITY_VERIFICATION_QUESTIONS_ERROR
        end

        def render_answers request, controller
          begin
            render_response = ->() {
              controller.render json: _ridp_verification_instance(request).build_answer_response
            }
          end

          BaseRenderer::execute render_response, controller, IDENTITY_VERIFICATION_ANSWERS_ERROR
        end

        #
        # Private
        #
        private

        class << self
          def _ridp_verification_instance request
            Mobile::Ridp::RidpVerification.new body: request.body.read
          end
        end
      end

      RidpRenderer.module_eval do
        module_function :render_questions
        module_function :render_answers
      end
    end
  end
end