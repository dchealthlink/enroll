module MobileRidpData
  shared_context 'ridp_data' do
    let (:request_json) {
      {person:
         {person_name:
            {person_surname: 'someLastName', person_given_name: 'someFirstName'},
          addresses: [
            {address:
               {type: 'home', address_line_1: 'Street name', location_city_name: 'City',
                location_state_code: 'TX', postal_code: '11111'}}
          ],
          emails: [
            {email: {type: 'home', email_address: 'some@some.com'}}
          ]
         },
       person_demographics:
         {ssn: '123456789', sex: 'male', birth_date: '19990101', is_incarcerated: 'false',
          created_at: '2017-03-30T025326Z', modified_at: '2017-03-30T025326Z'}
      }.to_json
    }
  end
end