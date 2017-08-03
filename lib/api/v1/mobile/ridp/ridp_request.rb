module Api
  module V1
    module Mobile::Ridp
      class RidpRequest < Api::V1::Mobile::Base
        attr_accessor :body

        def create_question_request
          begin
            #
            # Extract attributes from the request body.
            #
            person_name = ->() {@body[:person][:person_name]}
            person_surname = ->() {person_name.call[:person_surname]}
            person_given_name = ->() {person_name.call[:person_given_name]}
            addresses = ->() {@body[:person][:addresses]}
            single_address = ->(address) {address[:address]}
            address_type = ->(address) {single_address[address][:type]}
            address_line1 = ->(address) {single_address[address][:address_line_1]}
            location_city_name = ->(address) {single_address[address][:location_city_name]}
            location_state_code = ->(address) {single_address[address][:location_state_code]}
            postal_code = ->(address) {single_address[address][:postal_code]}
            emails = ->() {@body[:person][:emails]}
            phones = ->() {@body[:person][:phones]}
            single_email = ->(email) {email[:email]}
            single_phone = ->(phone) {phone[:phone]}
            email_type = ->(email) {single_email[email][:type]}
            phone_type = ->(phone) {single_phone[phone][:type]}
            email_address = ->(email) {single_email[email][:email_address]}
            phone_number = ->(phone) {single_phone[phone][:phone_number]}
            person_demographics = ->() {@body[:person_demographics]}
            ssn = ->() {person_demographics.call[:ssn]}
            sex = ->() {person_demographics.call[:sex]}
            birth_date = ->() {person_demographics.call[:birth_date]}

            create_id = ->(xml) {
              xml.id do
                xml.id '' # ID doesn't appear to be required.
              end
            }

            create_person_id = ->(xml) {
              xml.id do
                xml.id "urn:openhbx:hbx:dc0:resources:v1:person:hbx_id#" #  Person ID doesn't appear to be required.
              end
            }

            create_person_names = ->(xml, pii_data) {
              xml.person_name do
                person_surname.call.tap{|last_name|
                  xml.person_surname last_name
                  pii_data[:last_name] = last_name
                }

                person_given_name.call.tap{|first_name|
                  xml.person_given_name first_name
                  pii_data[:first_name] = first_name
                }
              end
            }

            create_addresses = ->(xml) {
              xml.addresses do
                addresses.call.each do |address|
                  xml.address do
                    xml.type "urn:openhbx:terms:v1:address_type##{address_type[address]}"
                    xml.address_line_1 address_line1[address]
                    xml.location_city_name location_city_name[address]
                    xml.location_state_code location_state_code[address]
                    xml.postal_code postal_code[address]
                  end
                end
              end
            }

            create_emails = ->(xml) {
              xml.emails do
                emails.call.each do |email|
                  xml.email do
                    xml.type "urn:openhbx:terms:v1:email_type##{email_type[email]}"
                    xml.email_address email_address[email]
                  end
                end
              end
            }

            create_phones = ->(xml) {
              xml.phones do
                phones.call.each do |phone|
                  xml.phone do
                    xml.type "urn:openhbx:terms:v1:phone_type##{phone_type[phone]}"
                    xml.full_phone_number phone_number[phone]
                    xml.is_preferred false
                  end
                end
              end
            }

            create_person = ->(xml, pii_data) {
              xml.person do
                create_person_id[xml]
                create_person_names[xml, pii_data]
                create_addresses[xml]
                create_emails[xml]
                create_phones[xml]
              end
            }

            create_timestamps = ->(xml) {
              DateTime.now.iso8601.tap {|date|
                xml.created_at date
                xml.modified_at date
              }
            }

            create_person_demographics = ->(xml, pii_data) {
              xml.person_demographics do
                ssn.call.tap{|ssn|
                  xml.ssn ssn
                  pii_data[:ssn] = ssn
                }

                xml.sex "urn:openhbx:terms:v1:gender##{sex.call}"

                birth_date.call.tap{|birth_date|
                  xml.birth_date birth_date
                  pii_data[:birth_date] = birth_date
                }

                create_timestamps[xml]
              end
            }
          end

          #
          # Build the XML request
          #
          pii_data = {}
          xml = Nokogiri::XML::Builder.new do |xml|
            xml.interactive_verification_start '', :xmlns => 'http://openhbx.org/api/terms/1.0' do
              xml.individual do
                create_id[xml]
                create_person[xml, pii_data]
                create_person_demographics[xml, pii_data]
              end
            end
          end
          {xml: xml, pii_data: pii_data}
        end

        def create_answer_request
          #
          # Extract attributes from the request body.
          #
          session_id = ->() {@body[:session_id]}
          transaction_id = ->() {@body[:transaction_id]}
          question_responses = ->() {@body[:question_response]}
          question_id = ->(response) {response[:question_id]}
          response_id = ->(response) {response[:answer][:response_id]}
          response_text = ->(response) {response[:answer][:response_text]}

          create_session_and_transaction_ids = ->(xml) {
            xml.session_id session_id.call
            xml.transaction_id transaction_id.call
          }

          create_answers = ->(xml) {
            question_responses.call.each do |response|
              xml.question_response do
                xml.question_id question_id[response]
                xml.answer do
                  xml.response_id response_id[response]
                  xml.response_text response_text[response]
                end
              end
            end
          }

          #
          # Build the XML request
          #
          Nokogiri::XML::Builder.new do |xml|
            xml.interactive_verification_question_response '', :xmlns => 'http://openhbx.org/api/terms/1.0' do
              create_session_and_transaction_ids[xml]
              create_answers[xml]
            end
          end
        end

      end
    end
  end
end
