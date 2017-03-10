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

        def format_date date
          date.strftime('%m-%d-%Y') if date.respond_to?(:strftime)
        end

        def ssn_masked person
          "***-**-#{person.ssn[5..9]}" if person.ssn
        end

      end
    end
  end
end