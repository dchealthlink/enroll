module Api
  module V1
    module Mobile::Renderer
      module RidpRenderer
        include BaseRenderer
        extend Api::V1::Mobile::Util::UrlUtil
        MESSAGE_SUFFIX = "not received or could not be processed"
        IDENTITY_VERIFICATION_QUESTIONS_ERROR = "Invalid JSON or valid identity verification questions were #{MESSAGE_SUFFIX}"
        IDENTITY_VERIFICATION_ANSWERS_ERROR = "valid identity verification response was #{MESSAGE_SUFFIX}"
        IDENTIFY_VERIFICATION_CHECK_OVERRIDE = "valid check override response was #{MESSAGE_SUFFIX}"

        def render_questions session, request, controller
          begin
            render_response = ->() {
              controller.response.headers['Location'] = verify_identity_answers_path
              controller.render json: _ridp_verification_instance(session, request).build_question_response
            }
          end

          BaseRenderer::execute render_response, controller, {error: IDENTITY_VERIFICATION_QUESTIONS_ERROR}
        end

        def render_answers session, request, params, controller
          begin
            render_response = ->() {
              _validate session
              controller.render json: _ridp_verification_instance(session, request, params).build_answer_response
            }
          end

          BaseRenderer::execute render_response, controller, {error: IDENTITY_VERIFICATION_ANSWERS_ERROR}
        end

        def check_override session, request, controller
          begin
            render_response = ->() {
              _validate session
              controller.render json: _ridp_verification_instance(session, request).build_check_override_response
            }
          end

          BaseRenderer::execute render_response, controller, {error: IDENTIFY_VERIFICATION_CHECK_OVERRIDE}
        end

        #
        # Private
        #
        private

        class << self
          def _ridp_verification_instance session, request, params=nil
            Mobile::Ridp::RidpVerification.new body: BaseRenderer::payload_body(request), session: session, params: params
          end

          def _validate session
            raise Mobile::Error::RIDPException.new({error: "This service requires a session and should be called after #{verify_identity_path}"}, 406) unless session && session[:pii_data]
          end
        end
      end

      RidpRenderer.module_eval do
        module_function :render_questions
        module_function :render_answers
        module_function :check_override
      end
    end
  end
end