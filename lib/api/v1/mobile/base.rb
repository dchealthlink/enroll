module Api
  module V1
    module Mobile
      class Base

        def initialize args={}
          args.each do |k, v|
            instance_variable_set("@#{k}", v) unless v.nil?
          end
        end

        #
        # Protected
        #
        protected

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

      end
    end
  end
end