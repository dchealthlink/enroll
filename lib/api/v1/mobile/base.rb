module Api
  module V1
    module Mobile
      class Base
        PEM_FILE = 'pem/symmetric.pem'

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

        def __summary_of_benefits_url plan
          document = plan.sbc_document
          return unless document
          document_download_path(*get_key_and_bucket(document.identifier).reverse)
            .concat("?content_type=application/pdf&filename=#{plan.name.gsub(/[^0-9a-z]/i, '')}.pdf&disposition=inline")
        end


        def __fetch_health_plans_json
          drupal_url = "https://dchealthlink.com/individuals/plan-info/health-plans/json"
          `curl #{drupal_url}`
        end

        # the other version of __summary_of_benefits retrieves the link in the enrolldb. sadly, this link requires
        # an authenticated session, so it's no use to plan shopping. We know there was a Drupal endpoint available
        # that provided this information in JSON, but it has been taken down (probably in connection with publishing
        # the new 2018 plans). While we wait for it to be restored, here's an ugly but functional screenscrape version
        def __summary_of_benefits_public_url hios_id, fetched
          fetched =~ /{[^}]*"hios_id":"#{hios_id}"[^}]*"pdf_file":"([^"]*)"/
          #Rails.logger.info "for #{plan.name}, found plan #{hios_id} with summary of benefits url #{$1}"  
          "https://dchealthlink.com#{$1.gsub("\\/", "/")}" if $1
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

      end
    end
  end
end