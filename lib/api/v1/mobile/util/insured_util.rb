module Api
  module V1
    module Mobile::Util
      class InsuredUtil < Api::V1::Mobile::Base

        def build_response
          begin
            insured_employee = ->() {
              @insured_employee ||= Api::V1::Mobile::Insured::InsuredEmployee.new person: @person
            }

            ins_individual = ->() {
              @insured_individual ||= Api::V1::Mobile::Insured::InsuredIndividual.new person: @person
            }

            # Returns the HBX enrollment IDs for the given array of enrollments.
            employee_enrollment_ids = ->(ee_enrollments) {
              ee_enrollments.map {|x|
                [x[:health][:hbx_enrollment_id], x[:dental][:hbx_enrollment_id]]
              }.flatten.compact
            }

            # We don't want to duplicate the employee related enrollments with the IVL enrollments.
            filter_duplicates = ->(ivl_enrollments, ee_enrollments) {
              %i{health dental}.each {|kind|
                ivl_enrollments.delete_if {|enr|
                  next unless enr[kind]
                  employee_enrollment_ids[ee_enrollments].include? enr[kind][:hbx_enrollment_id]
                }
              }
            }

            # Sorts the enrollments in chronologically descending order.
            sort_enrollments = ->(enrollments) {
              sorted_enrollments = []
              enrollments.each {|enr| sorted_enrollments << {start_on: enr[:start_on], enrollment: enr}}

              enrollments = []
              sorted_enrollments.sort_by {|enr| enr[:start_on]}.reverse.each {|x| enrollments << x[:enrollment]}
              enrollments
            }

            # Returns a combination of IVL (individual) and EE (employee) enrollments.
            all_enrollments = ->(ins_dependents) {
              dependent_count = JSON.parse(ins_dependents)['dependents'].size
              ee_enrollments = insured_employee.call.ins_enrollments(dependent_count).flatten
              ivl_enrollments = ins_individual.call.ins_enrollments(dependent_count).flatten
              filter_duplicates[ivl_enrollments, ee_enrollments]

              Jbuilder.encode do |json|
                json.enrollments sort_enrollments[ivl_enrollments] + sort_enrollments[ee_enrollments]
              end
            }
          end

          result = {}
          ins_dependents = ins_individual.call.ins_dependents
          __merge_these result, ins_individual.call.basic_person, ins_individual.call.addresses,
                        ins_dependents, all_enrollments[ins_dependents], insured_employee.call.ins_employments
          result
        end

      end
    end
  end
end