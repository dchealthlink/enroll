module Api
  module V2
    module Mobile::Error
      class RIDPException < StandardError
        attr_accessor :message, :code

        def initialize message, code
          super message
          @code = code
          @message = message
        end
      end
    end
  end
end