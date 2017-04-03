module Api
  module V1
    module Mobile::Renderer
      module MyBaseRenderer
        include BaseRenderer

        def render_details current_user, params, controller
          security = Mobile::Util::SecurityUtil.new user: current_user, params: params
          _render_response security.employer_profile && _can_view?(security), security.employer_profile,
                           params, controller
        end

        def render_my_details current_user, params, controller
          employer_profile = Mobile::Util::EmployerUtil.employer_profile_for_user current_user
          _render_response !employer_profile.nil?, employer_profile, params, controller
        end

      end
    end
  end
end