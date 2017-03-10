module Api
  module V1
    module Mobile::Enrollment
      class IndividualEnrollment < BaseEnrollment

        def populate_enrollments
          result = {}
          __health_and_dental! result, @person.primary_family.households.map(&:hbx_enrollments).flatten
          result
        end

        #
        # Private
        #
        private

        def _enrollment_details coverage_kind, enrollment
          {
              hbx_enrollment_id: enrollment.id,
              status: __status_label_for(enrollment.aasm_state),
              total_premium: enrollment.total_premium,
              plan_name: enrollment.plan.try(:name),
              plan_type: enrollment.plan.try(:plan_type),
              metal_level: enrollment.plan.try(coverage_kind == :health ? :metal_level : :dental_level),
              benefit_group_name: enrollment.try(:benefit_group).try(:title)
          }
        end

      end
    end
  end
end