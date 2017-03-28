module Api
  module V1
    module Mobile::Util
      class InsuredUtil < Api::V1::Mobile::Base

        def build_insured_json
          begin
            insured_employee = ->() {
              @insured_employee ||= Api::V1::Mobile::Insured::InsuredEmployee.new person: @person
            }

            filter_duplicates = ->(ivl_enrollments) {
              ee_enrollments = insured_employee.call.ins_enrollments.flatten
              ee_enrollment_ids = ee_enrollments.map {
                |e| e['health'][:hbx_enrollment_id] || e['dental'][:hbx_enrollment_id] }.compact
              ivl_enrollments.map { |enr|
                %w{health dental}.each { |kind|
                  next unless enr[kind]
                  enr.delete(kind) if ee_enrollment_ids.include? enr[kind][:hbx_enrollment_id]
                }
              }
              return ivl_enrollments, ee_enrollments
            }

            ins_individual = ->() {
              @insured_individual ||= Api::V1::Mobile::Insured::InsuredIndividual.new person: @person
            }

            all_enrollments = ->() {
              Jbuilder.encode do |json|
                filter_duplicates[ins_individual.call.ins_enrollments.flatten].tap { |ivl_enrollments, ee_enrollments|
                  json.enrollments ivl_enrollments + ee_enrollments
                }
              end
            }

            merge_these = ->(hash, *details) { details.each { |m| hash.merge! JSON.parse(m) } }
          end

          result = {}
          merge_these.call result, ins_individual.call.basic_person, ins_individual.call.addresses, ins_individual.call.ins_dependents
          merge_these.call result, all_enrollments.call
          merge_these.call result, insured_employee.call.ins_employments
          result
        end

      end
    end
  end
end