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
              qhps.first.qhp_service_visits.map {|service_visit| services_response[service_visit]}
            }
          end

          hios_id && active_year && coverage_kind ? services_rates_details[active_year, coverage_kind, hios_id] : {}
        end

        #
        # Protected
        #
        protected
        
        def __add_default_fields! start_on, end_on, response
          response[:start_on] = start_on
          response[:end_on] = end_on
          response[:health] = {status: 'Not Enrolled'}
          response[:dental] = {status: 'Not Enrolled'}
        end

        def __initialize_enrollment hbx_enrollment, coverage_kind
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

            enrollment_plan_fields = ->(enrollment, result) {
              ENROLLMENT_PLAN_FIELDS.each do |field|
                value = enrollment.plan.try(field)
                result[field] = value if value
              end
            }

            other_enrollment_fields = ->(enrollment, result) {
              return unless enrollment.plan
              result[:carrier_name] = enrollment.plan.carrier_profile.legal_name
              result[:carrier_logo] = display_carrier_logo Maybe.new enrollment.plan
              result[:summary_of_benefits_url] = __summary_of_benefits_url enrollment.plan
              enrollment_plan_fields[enrollment, result]
            }

            services_rates_url = ->(enrollment, coverage_kind, result) {
              return unless enrollment.plan
              result[:services_rates_url] = services_rates_path enrollment.plan.hios_id, enrollment.plan.active_year, coverage_kind
            }

            enrollment_details = ->(coverage_kind, enrollment) {
              {
                health_link_id: enrollment.hbx_id,
                hbx_enrollment_id: enrollment.id,
                status: __status_label_for(enrollment.aasm_state),
                plan_name: enrollment.plan.try(:name),
                plan_type: enrollment.plan.try(:plan_type),
                metal_level: enrollment.plan.try(coverage_kind == 'health' ? :metal_level : :dental_level)
              }.merge __specific_enrollment_fields(enrollment)
            }
          end

          result = enrollment_details[coverage_kind, hbx_enrollment]
          other_enrollment_fields[hbx_enrollment, result]
          enrollment_termination[hbx_enrollment, result]
          enrollment_waived[hbx_enrollment, result]
          services_rates_url[hbx_enrollment, coverage_kind, result]
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

        def __health_and_dental! result, enrollment
          result[enrollment.coverage_kind.to_sym] = __initialize_enrollment enrollment, enrollment.coverage_kind
          result
        end

        def __has_enrolled? response, enrollment
          response[enrollment.coverage_kind.to_sym] &&
            response[enrollment.coverage_kind.to_sym][:status] == EnrollmentConstants::ENROLLED
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