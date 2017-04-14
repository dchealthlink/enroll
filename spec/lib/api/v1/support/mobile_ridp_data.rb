module MobileRidpData
  shared_context 'ridp_data' do
    let (:question_request_json) {
      {
        person:
          {
            person_name:
              {
                person_surname: 'someLastName',
                person_given_name: 'someFirstName'
              },
            addresses: [
              {
                address:
                  {
                    type: 'home',
                    address_line_1: 'Street name',
                    location_city_name: 'City',
                    location_state_code: 'TX',
                    postal_code: '11111'
                  }
              }
            ],
            emails: [
              {
                email:
                  {
                    type: 'home',
                    email_address: 'some@some.com'
                  }
              }
            ]
          },
        person_demographics:
          {
            ssn: '123456789',
            sex: 'male',
            birth_date: '19990101',
            is_incarcerated: 'false',
            created_at: '2017-03-30T025326Z',
            modified_at: '2017-03-30T025326Z'
          }
      }.to_json
    }

    let(:answer_request_json) {
      {
        ssn: '111222333',
        session_id: 'AB783917E63E4CA345448C600928D632.pidd1v-1304180857460210166972210',
        transaction_id: 'c5f1-52-3a57',
        question_response: [
          {
            question_id: '1',
            answer: {
              response_id: '1',
              response_text: 'AUGUSTA'
            }
          },
          {
            question_id: '2',
            answer: {
              response_id: '1',
              response_text: '1965 to 1974'
            }
          },
          {
            question_id: '3',
            answer: {
              response_id: '1',
              response_text: 'HIGH SCHOOL DIPLOMA'
            }
          },
          {
            question_id: '4',
            answer: {
              response_id: '1',
              response_text: '2'
            }
          }
        ]
      }.to_json
    }
  end
end