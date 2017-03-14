module Api
  module V1
    module Mobile::Enrollment
      class BaseEnrollment < Api::V1::Mobile::Base
        include ApplicationHelper
        include Api::V1::Mobile::Util::UrlUtil
        Util = Api::V1::Mobile::Util
        ENROLLMENT_PLAN_FIELDS = [:plan_type, :deductible, :family_deductible, :provider_directory_url, :rx_formulary_url]

        def services_rates hios_id, active_year, coverage_kind
          hios_id && active_year && coverage_kind ? _services_rates_details(active_year, coverage_kind, hios_id) : {}
        end

        #
        # Protected
        #
        protected

        def __initialize_enrollment hbx_enrollments, coverage_kind
          enrollment = hbx_enrollments.flatten.detect { |e| e.coverage_kind == coverage_kind } unless !hbx_enrollments || hbx_enrollments.empty?
          result = enrollment ? _enrollment_details(coverage_kind, enrollment) : {status: 'Not Enrolled'}
          _other_enrollment_fields enrollment, result
          _enrollment_termination! enrollment, result
          _enrollment_waived! enrollment, result
          _services_rates_url! enrollment, coverage_kind, result
          result
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

        def _services_rates_url! enrollment, coverage_kind, result
          return unless enrollment && enrollment.plan
          result[:services_rates_url] = services_rates_path enrollment.plan.hios_id, enrollment.plan.active_year, coverage_kind
        end

        def _services_rates_details active_year, coverage_kind, hios_id
          qhps = Products::QhpCostShareVariance.find_qhp_cost_share_variances [hios_id], active_year, coverage_kind
          return {} if qhps.empty?
          qhps.first.qhp_service_visits.map do |service_visit|
            if service_visit.present?
              {
                  service: service_visit.visit_type,
                  copay: service_visit.copay_in_network_tier_1,
                  coinsurance: service_visit.co_insurance_in_network_tier_1.present? ? service_visit.co_insurance_in_network_tier_1 : 'N/A'
              }
            end
          end
        end

        def _other_enrollment_fields enrollment, result
          return unless enrollment && enrollment.plan
          ENROLLMENT_PLAN_FIELDS.each do |field|
            value = enrollment.plan.try(field)
            result[field] = value if value
          end
          result[:carrier] = _carrier enrollment
        end

        def _carrier enrollment
          carrier_name = enrollment.plan.carrier_profile.legal_name
          {
              name: carrier_name,
              summary_of_benefits_url: _summary_of_benefits(enrollment)
          }
        end

        def _enrollment_termination! enrollment, result
          return unless result[:status] == EnrollmentConstants::TERMINATED
          result[:terminated_on] = format_date enrollment.terminated_on
          result[:terminate_reason] = enrollment.terminate_reason
        end

        def _enrollment_waived! enrollment, result
          return unless result[:status] == EnrollmentConstants::WAIVED
          result[:waived_on] = format_date(enrollment.submitted_at || enrollment.created_at)
          result[:waiver_reason] = enrollment.waiver_reason
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