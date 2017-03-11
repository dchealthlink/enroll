module Api
  module V1
    module Mobile::Enrollment
      class BaseEnrollment < Api::V1::Mobile::Base
        include ApplicationHelper
        include Api::V1::Mobile::Util::UrlUtil
        Util = Api::V1::Mobile::Util
        ENROLLMENT_PLAN_FIELDS = [:plan_type, :deductible, :family_deductible, :provider_directory_url, :rx_formulary_url]

        #
        # Protected
        #
        protected

        def __initialize_enrollment hbx_enrollments, coverage_kind
          enrollment = hbx_enrollments.flatten.detect { |e| e.coverage_kind == coverage_kind } unless !hbx_enrollments || hbx_enrollments.empty?
          rendered_enrollment = enrollment ? _enrollment_details(coverage_kind, enrollment) : {status: 'Not Enrolled'}
          _other_enrollment_fields enrollment, rendered_enrollment
          _enrollment_termination! enrollment, rendered_enrollment
          _enrollment_waived! enrollment, rendered_enrollment
          rendered_enrollment
        end

        def __status_label_for enrollment_status
          {
              EnrollmentConstants::WAIVED => HbxEnrollment::WAIVED_STATUSES,
              EnrollmentConstants::ENROLLED => HbxEnrollment::ENROLLED_STATUSES,
              EnrollmentConstants::TERMINATED => HbxEnrollment::TERMINATED_STATUSES,
              EnrollmentConstants::RENEWING => HbxEnrollment::RENEWAL_STATUSES
          }.inject(nil) do |result, (label, enrollment_statuses)|
            enrollment_statuses.include?(enrollment_status.to_s) ? label : result
          end
        end

        def __health_and_dental! result, enrollments
          %w{health dental}.each { |coverage| result[coverage] = __initialize_enrollment enrollments, coverage }
        end

        def _enrollment_details coverage_kind, enrollment
          {
              hbx_enrollment_id: enrollment.id,
              status: __status_label_for(enrollment.aasm_state),
              plan_name: enrollment.plan.try(:name),
              plan_type: enrollment.plan.try(:plan_type),
              metal_level: enrollment.plan.try(coverage_kind == :health ? :metal_level : :dental_level),
              benefit_group_name: enrollment.try(:benefit_group).try(:title),
              total_premium: enrollment.total_premium
          }.merge __specific_enrollment_fields(enrollment)
        end

        #
        # Private
        #
        private

        def _other_enrollment_fields enrollment, rendered_enrollment
          if enrollment && enrollment.plan
            ENROLLMENT_PLAN_FIELDS.each do |field|
              value = enrollment.plan.try(field)
              rendered_enrollment[field] = value if value
            end
            rendered_enrollment[:carrier] = _carrier enrollment
          end
        end

        def _carrier enrollment
          carrier_name = enrollment.plan.carrier_profile.legal_name
          {
              name: carrier_name,
              summary_of_benefits_url: _summary_of_benefits(enrollment)
          }
        end

        def _enrollment_termination! enrollment, rendered_enrollment
          return unless rendered_enrollment[:status] == EnrollmentConstants::TERMINATED
          rendered_enrollment[:terminated_on] = format_date enrollment.terminated_on
          rendered_enrollment[:terminate_reason] = enrollment.terminate_reason
        end

        def _enrollment_waived! enrollment, rendered_enrollment
          return unless rendered_enrollment[:status] == EnrollmentConstants::WAIVED
          rendered_enrollment[:waived_on] = format_date(enrollment.submitted_at || enrollment.created_at)
          rendered_enrollment[:waiver_reason] = enrollment.waiver_reason
        end

        def _summary_of_benefits enrollment
          document = enrollment.plan.sbc_document
          document_download_path(*get_key_and_bucket(document.identifier).reverse)
              .concat("?content_type=application/pdf&filename=#{enrollment.plan.name.gsub(/[^0-9a-z]/i, '')}.pdf&disposition=inline") if document
        end
      end

      module EnrollmentConstants
        WAIVED = 'Waived'
        TERMINATED = 'Terminated'
        ENROLLED = 'Enrolled'
        RENEWING = 'Renewing'
      end

    end
  end
end