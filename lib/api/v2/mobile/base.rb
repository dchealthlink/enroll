require 'open-uri'

module Api
  module V2
    module Mobile
      class Base
        PEM_FILE = 'pem/symmetric.pem'

        HBX_ROOT = "https://dchealthlink.com"
        DRUPAL_PLANS_URL = "https://dchealthlink.com/individuals/plan-info/health-plans/json"

        def initialize args={}
          args.each do |k, v|
            instance_variable_set("@#{k}", v) unless v.nil?
          end
        end

        #
        # Called by ApplicationHelper.display_carrier_logo via:
        # - PlanResponse::_render_links!
        # - BaseEnrollment::__initialize_enrollment
        #
        def image_tag source, options
          nok = Nokogiri::HTML ActionController::Base.helpers.image_tag source, options
          nok.at_xpath('//img/@src').value
        end

        #
        # Protected
        #
        protected

        def __merge_these (hash, *details)
          details.each {|m| hash.merge! JSON.parse(m)}
        end

        # old version, using authenticated URLs from the database. instead, we now fetch public URLs from drupal
        # def __summary_of_benefits_url plan
        #   document = plan.sbc_document
        #   return unless document
        #   document_download_path(*get_key_and_bucket(document.identifier).reverse)
        #     .concat("?content_type=application/pdf&filename=#{plan.name.gsub(/[^0-9a-z]/i, '')}.pdf&disposition=inline")
        # end

        def __summary_of_benefits_url plan
          market = plan.market.to_s == "individual" ? "Individual" : "Small Group"
          coverage_kind = plan.coverage_kind.to_sym
          hios_id = plan.hios_base_id
          plan_year = plan.active_year

          plans = PlanPdfLinks.plan_pdf_links[hios_id]
          if plans
            plan = plans.detect do |p|
              p[:coverage_kind] == coverage_kind && p[:year] == plan_year && p[:market] == market
            end
            plan[:pdf_link] if plan
          end
        end

        def __format_date date
          date.strftime('%m-%d-%Y') if date.respond_to?(:strftime)
        end

        def __ssn_masked person
          "***-**-#{person.ssn[5..9]}" if person.ssn
        end

        def __is_current_or_upcoming? start_on
          TimeKeeper.date_of_record.tap {|now| (now - 1.year..now + 1.year).include? start_on}
        end

        def __pem_file_exists?
          pem_file = "#{Rails.root}/".concat(ENV['MOBILE_PEM_FILE'] || PEM_FILE)
          raise 'pem file is missing' unless File.file? pem_file
          pem_file
        end

        #
        # If the client sends a SSN, we use that to find the user. If there is no SSN, we rely on a combination of
        # First Name, Last Name and Date of Birth to look up the user.
        #
        def __find_person
          begin
            # Returns a person for the given DOB, First Name and Last Name.
            find_by_dob_and_names = ->() {
              pers = Person.match_by_id_info dob: @pii_data[:birth_date],
                                             last_name: @pii_data[:last_name],
                                             first_name: @pii_data[:first_name]
              pers.first if pers.present?
            }
          end #lambda

          raise 'Invalid Request' unless @pii_data

          # If there is NO person found for either the given SSN or a combination of DOB/FirstName/LastName, check the roster.
          @pii_data[:ssn].present? ? Person.find_by_ssn(@pii_data[:ssn]) : find_by_dob_and_names.call
        end

        class PlanPdfLinks
          #
          #  fetch and globally cache the drupal JSON plan info. It looks like this:
          #   {"id":"768","created":"20150928123937","lastmod":"20151116123404","enabled":"1","hios_id":"78079DC0220022",
          #   "carrier":"CareFirst","group_year":"2016 Small Group","type":"PPO",
          #   "full_name":"BluePreferred PPO HSA\/HRA Silver 1500","metal":"Silver",
          #   "pdf":"2016\/carefirst\/shop\/ghmsi_bluepreferred_ppo_hsa_hra_silver_1500_shop.pdf",
          #   "coverage":"Nationwide In-Network","coverage_details":"All States; All Territories, except Midway Islands",
          #   "is_dental":"0","is_health":"1","formulary_url":"http:\/\/www.carefirst.com\/acarx",
          #   "contracts_plan_url":"https:\/\/content.carefirst.com\/sbc\/contracts\/APHDB66ARXCDBB6M.pdf",
          #   "pdf_file":"\/sites\/default\/files\/v2\/download\/health-pl    ans\/2016\/carefirst\/shop\/ghmsi_bluepreferred_ppo_hsa_hra_silver_1500_shop.pdf",
          #   "metal_color":"delta","span_class":"silver"}
          #
          #  The server must be rebooted when the plans are updated.
          #
          def self.plan_pdf_links
            @plan_pdf_links ||= begin
              ivl_plans = []
              result = open(DRUPAL_PLANS_URL).try(:read)
              if result
                parsed = JSON.parse result
                if parsed
                  ivl_plans = parsed.select { |x| x['enabled'].to_i == 1 }
                end
              end
  
              plans = {}
              ivl_plans.each do |p|
                plan = {}
                pdf = p['pdf_file']
                plan[:pdf_link] = pdf ? "#{HBX_ROOT}#{pdf}" : nil
                if p['group_year'] =~ /(\d*) ([\w ]*)/
                  plan[:year] = $1.to_i
                  plan[:market] = $2
                end
                if p['is_health'].to_i == 1
                  plan[:coverage_kind] = :health
                elsif p['is_dental'].to_i == 1
                  plan[:coverage_kind] = :dental
                end

                plans[p['hios_id']] ||= []
                plans[p['hios_id']] << plan
              end
              plans
            end
          end
        end #class PlanPdfLinks
  
      end # class Base
    end   # module Mobile
  end     # module V2
end       # modile Api
