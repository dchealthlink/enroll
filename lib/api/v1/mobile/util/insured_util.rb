module Api
  module V1
    module Mobile::Util
      class InsuredUtil < Api::V1::Mobile::Base

        def build_insured_json
          result = {}
          _merge_these result, _insured_individual.basic_person, _insured_individual.addresses, _insured_individual.ins_dependents
          _merge_these result, _all_enrollments
          _merge_these result, _insured_employee.ins_employments
          result
        end

        #
        # Private
        #
        private

        def _all_enrollments
          Jbuilder.encode do |json|
            _filter_duplicates _insured_individual.ins_enrollments.flatten do |ivl_enrollments, ee_enrollments|
              json.enrollments ivl_enrollments + ee_enrollments
            end
          end
        end

        def _filter_duplicates ivl_enrollments
          ee_enrollments = _insured_employee.ins_enrollments.flatten
          ee_enrollment_ids = ee_enrollments.map {
              |e| e['health'][:hbx_enrollment_id] || e['dental'][:hbx_enrollment_id] }.compact
          ivl_enrollments.map { |enr|
            %w{health dental}.each { |kind|
              enr.delete(kind) if ee_enrollment_ids.include? enr[kind][:hbx_enrollment_id]
            }
          }
          yield ivl_enrollments, ee_enrollments
        end

        def _merge_these hash, *details
          details.each { |m| hash.merge! JSON.parse(m) }
        end

        def _insured_individual
          @insured_individual ||= Api::V1::Mobile::Insured::InsuredIndividual.new person: @person
        end

        def _insured_employee
          @insured_employee ||= Api::V1::Mobile::Insured::InsuredEmployee.new person: @person
        end

      end
    end
  end
end