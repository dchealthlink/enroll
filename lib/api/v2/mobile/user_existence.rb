module Api
  module V2
    module Mobile
      class UserExistence < Api::V2::Mobile::Base
        include ActionView::Helpers::NumberHelper
        include Api::V2::Mobile::Response::UserExistenceResponse

        #
        # Check if the user exists in Enroll (as a registered user who can login), or in the Roster (as a dependent
        # of another primary applicant).
        #
        def check_user_existence
          person = __find_person
          person ? primary_applicant_response(person): user_not_found_response
        end

        #
        # Private
        #
        private

        def _add_employer_phone employer_profile, staff
          if staff[employer_profile.id].present?
            number_to_phone(staff[employer_profile.id].first.phones.first.try(:full_phone_number), area_code: true)
          end
        end

      end
    end
  end
end