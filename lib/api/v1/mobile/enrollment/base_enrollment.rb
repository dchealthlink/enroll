module Api
  module V1
    module Mobile::Enrollment
      class BaseEnrollment < Api::V1::Mobile::Base
        include ApplicationHelper
        include Api::V1::Mobile::Util::UrlUtil
        Util = Api::V1::Mobile::Util
        ENROLLMENT_PLAN_FIELDS = [:plan_type, :deductible, :family_deductible, :provider_directory_url, :rx_formulary_url]

        def services_rates hios_id, active_year, coverage_kind
          begin
            services_response = ->(service_visit) {
              return unless service_visit.present?
              co_insurance = service_visit.co_insurance_in_network_tier_1
              {
                service: service_visit.visit_type,
                copay: service_visit.copay_in_network_tier_1,
                coinsurance: co_insurance.present? ? co_insurance : 'N/A'
              }
            }

            services_rates_details = ->(active_year, coverage_kind, hios_id) {
              qhps = Products::QhpCostShareVariance.find_qhp_cost_share_variances [hios_id], active_year, coverage_kind
              return {} if qhps.empty?
              qhps.first.qhp_service_visits.map { |service_visit| services_response[service_visit] }
            }
          end

          hios_id && active_year && coverage_kind ? services_rates_details[active_year, coverage_kind, hios_id] : {}
        end

        #
        # Protected
        #
        protected

        def __initialize_enrollment hbx_enrollments, coverage_kind
          begin
            enrollment_waived = ->(enrollment, result) {
              return unless result[:status] == EnrollmentConstants::WAIVED
              result[:waived_on] = format_date(enrollment.submitted_at || enrollment.created_at)
              result[:waiver_reason] = enrollment.waiver_reason
            }

            enrollment_termination = ->(enrollment, result) {
              return unless result[:status] == EnrollmentConstants::TERMINATED
              result[:terminated_on] = format_date enrollment.terminated_on
              result[:terminate_reason] = enrollment.terminate_reason
            }

            carrier = ->(enrollment) {
              carrier_name = enrollment.plan.carrier_profile.legal_name
              {
                name: carrier_name,
                summary_of_benefits_url: __summary_of_benefits_url(enrollment.plan)
              }
            }

            other_enrollment_fields = ->(enrollment, result) {
              return unless enrollment && enrollment.plan
              ENROLLMENT_PLAN_FIELDS.each do |field|
                value = enrollment.plan.try(field)
                result[field] = value if value
              end
              result[:carrier] = carrier[enrollment]
            }

            services_rates_url = ->(enrollment, coverage_kind, result) {
              return unless enrollment && enrollment.plan
              result[:services_rates_url] = services_rates_path enrollment.plan.hios_id, enrollment.plan.active_year, coverage_kind
            }

            enrollment_details = ->(coverage_kind, enrollment) {
              {
                hbx_enrollment_id: enrollment.id,
                status: __status_label_for(enrollment.aasm_state),
                plan_name: enrollment.plan.try(:name),
                plan_type: enrollment.plan.try(:plan_type),
                metal_level: enrollment.plan.try(coverage_kind == :health ? :metal_level : :dental_level),
                benefit_group_name: enrollment.try(:benefit_group).try(:title),
                total_premium: enrollment.total_premium
              }.merge __specific_enrollment_fields(enrollment)
            }
          end

          enrollment = hbx_enrollments.flatten.detect { |e| e.coverage_kind == coverage_kind } unless !hbx_enrollments || hbx_enrollments.empty?
          result = enrollment ? enrollment_details[coverage_kind, enrollment] : {status: 'Not Enrolled'}
          other_enrollment_fields[enrollment, result]
          enrollment_termination[enrollment, result]
          enrollment_waived[enrollment, result]
          services_rates_url[enrollment, coverage_kind, result]
          result
        end

        def __status_label_for enrollment_status
          {
            EnrollmentConstants::WAIVED => HbxEnrollment::WAIVED_STATUSES,
            EnrollmentConstants::ENROLLED => HbxEnrollment::ENROLLED_AND_RENEWAL_STATUSES,
            EnrollmentConstants::TERMINATED => HbxEnrollment::TERMINATED_STATUSES
          }.inject(nil) do |result, (label, enrollment_statuses)|
            enrollment_statuses.include?(enrollment_status.to_s) ? label : result
          end
        end

        def __health_and_dental! result, enrollments
          %w{health dental}.each { |coverage| result[coverage] = __initialize_enrollment enrollments, coverage }
        end
      end

      module EnrollmentConstants
        WAIVED = 'Waived'
        TERMINATED = 'Terminated'
        ENROLLED = 'Enrolled'
      end

    end
  end
end