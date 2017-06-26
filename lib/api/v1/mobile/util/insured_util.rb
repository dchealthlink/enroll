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

            # Returns a combination of IVL (individual) and EE (employee) enrollments.
            all_enrollments = ->() {
              ee_enrollments = insured_employee.call.ins_enrollments.flatten
              ivl_enrollments = ins_individual.call.ins_enrollments.flatten
              filter_duplicates[ivl_enrollments, ee_enrollments]

              Jbuilder.encode do |json|
                json.enrollments ivl_enrollments + ee_enrollments
              end
            }
          end

          result = {}
          __merge_these result, ins_individual.call.basic_person, ins_individual.call.addresses,
                        ins_individual.call.ins_dependents, all_enrollments.call, insured_employee.call.ins_employments
          result
        end

      end
    end
  end
end