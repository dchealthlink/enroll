module Api
  module V1
    module Mobile
      class Base
        ENROLL_PRODUCTION_URL = 'https://enroll.dchealthlink.com'

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
          begin
            #
            # Android devices have trouble reading an image with a self-signed certificate
            # so we are just temporarily hardwiring this to go to prod enroll until either:
            # 1) we get a proper certificate on the preprod box, or
            # 2) we ship to production, in which case we can remove this and it will work on prod
            # and fail gracefully on preprod.
            #
            # TODO Kanban card 8448 tracks this temporary fix's pending removal
            #
            android_hack_carrier_logo = ->(logo) {"#{ENROLL_PRODUCTION_URL}#{logo}"}
          end

          nok = Nokogiri::HTML ActionController::Base.helpers.image_tag source, options
          android_hack_carrier_logo[nok.at_xpath('//img/@src').value]
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

        def __format_date date
          date.strftime('%m-%d-%Y') if date.respond_to?(:strftime)
        end

        def __ssn_masked person
          "***-**-#{person.ssn[5..9]}" if person.ssn
        end

        def __is_current_or_upcoming? start_on
          TimeKeeper.date_of_record.tap {|now| (now - 1.year..now + 1.year).include? start_on}
        end

      end
    end
  end
end