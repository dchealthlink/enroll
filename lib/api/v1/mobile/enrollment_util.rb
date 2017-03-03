module Api
  module V1
    module Mobile

      module EnrollmentConstants
        WAIVED = 'Waived'
        TERMINATED = 'Terminated'
        ENROLLED = 'Enrolled'
        RENEWING = 'Renewing'
      end

      class EnrollmentUtil < BaseUtil
        include UrlUtil
        include ApplicationHelper

        attr_accessor :grouped_bga_enrollments

        def initialize args={}
          super args
          @assignments = current_or_upcoming_assignments if @benefit_group_assignments
        end

        def benefit_group_assignment_ids enrolled, waived, terminated
          yield bg_assignment_ids(enrolled), bg_assignment_ids(waived), bg_assignment_ids(terminated)
        end

        def employee_enrollments employee=nil
          @assignments.map do |assignment|
            hbx_enrollments = @grouped_bga_enrollments[assignment.id.to_s] unless !@grouped_bga_enrollments || @grouped_bga_enrollments.empty?
            enrollment_year = enrollment_hash employee, assignment
            %w{health dental}.each do |coverage_kind|
              enrollments = hbx_enrollments ? hbx_enrollments : assignment.hbx_enrollments
              enrollment, rendered_enrollment = initialize_enrollment enrollments, coverage_kind

              if enrollment && enrollment.plan
                EmployeeUtil::ROSTER_ENROLLMENT_PLAN_FIELDS_TO_RENDER.each do |field|
                  value = enrollment.plan.try(field)
                  rendered_enrollment[field] = value if value
                end
                rendered_enrollment[:carrier] = carrier enrollment if employee
              end

              enrollment_termination! enrollment, rendered_enrollment
              enrollment_waived! enrollment, rendered_enrollment
              enrollment_year[coverage_kind] = rendered_enrollment
            end
            enrollment_year
          end
        end

        #
        # Private
        #
        private

        def enrollment_hash employee, assignment
          enrollment = {}
          enrollment.merge! employer_profile_id: employee.employer_profile_id if employee
          enrollment.merge! start_on: assignment.plan_year.start_on
          enrollment
        end

        def carrier enrollment
          carrier_name = enrollment.plan.carrier_profile.legal_name
          {
              name: carrier_name,
              terms_and_conditions_url: terms_and_conditions(enrollment)
          }
        end

        def terms_and_conditions enrollment
          document = enrollment.plan.sbc_document
          document_download_path(*get_key_and_bucket(document.identifier).reverse)
              .concat("?content_type=application/pdf&filename=#{enrollment.plan.name.gsub(/[^0-9a-z]/i, '')}.pdf&disposition=inline") if document
        end

        def current_or_upcoming_assignments
          @benefit_group_assignments.select { |a| PlanYearUtil.new(plan_year: a.plan_year).is_current_or_upcoming? }
        end

        def bg_assignment_ids statuses
          active_employer_sponsored_health_enrollments.select do |enrollment|
            statuses.include? (enrollment.aasm_state)
          end.map(&:benefit_group_assignment_id)
        end

        def active_employer_sponsored_health_enrollments
          @active_employer_sponsored_health_enrollments ||= @all_enrollments.select do |enrollment|
            enrollment.kind == 'employer_sponsored' &&
                enrollment.coverage_kind == 'health' &&
                enrollment.is_active
          end.compact.sort do |e1, e2|
            e2.submitted_at.to_i <=> e1.submitted_at.to_i # most recently submitted first
          end.uniq do |e|
            e.benefit_group_assignment_id # only the most recent per employee
          end
        end

        def enrollment_termination! enrollment, rendered_enrollment
          return unless rendered_enrollment[:status] == EnrollmentConstants::TERMINATED
          rendered_enrollment[:terminated_on] = format_date enrollment.terminated_on
          rendered_enrollment[:terminate_reason] = enrollment.terminate_reason
        end

        def enrollment_waived! enrollment, rendered_enrollment
          return unless rendered_enrollment[:status] == EnrollmentConstants::WAIVED
          rendered_enrollment[:waived_on] = format_date(enrollment.submitted_at || enrollment.created_at)
          rendered_enrollment[:waiver_reason] = enrollment.waiver_reason
        end

        def initialize_enrollment hbx_enrollments, coverage_kind
          enrollment = hbx_enrollments.flatten.detect { |e| e.coverage_kind == coverage_kind } unless !hbx_enrollments || hbx_enrollments.empty?
          rendered_enrollment = enrollment ? enrollment_details(coverage_kind, enrollment) : {status: 'Not Enrolled'}
          return enrollment, rendered_enrollment
        end

        def enrollment_details coverage_kind, enrollment
          {
              status: status_label_for(enrollment.aasm_state),
              employer_contribution: enrollment.total_employer_contribution,
              employee_cost: enrollment.total_employee_cost,
              total_premium: enrollment.total_premium,
              plan_name: enrollment.plan.try(:name),
              plan_type: enrollment.plan.try(:plan_type),
              metal_level: enrollment.plan.try(coverage_kind == :health ? :metal_level : :dental_level),
              benefit_group_name: enrollment.try(:benefit_group).try(:title)
          }
        end

        def status_label_for enrollment_status
          {
              EnrollmentConstants::WAIVED => HbxEnrollment::WAIVED_STATUSES,
              EnrollmentConstants::ENROLLED => HbxEnrollment::ENROLLED_STATUSES,
              EnrollmentConstants::TERMINATED => HbxEnrollment::TERMINATED_STATUSES,
              EnrollmentConstants::RENEWING => HbxEnrollment::RENEWAL_STATUSES
          }.inject(nil) do |result, (label, enrollment_statuses)|
            enrollment_statuses.include?(enrollment_status.to_s) ? label : result
          end
        end

      end
    end
  end
end