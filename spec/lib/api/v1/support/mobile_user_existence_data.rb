module MobileUserExistenceData
  shared_context 'user_existence_data' do
    let (:request_json) {
      {
        person_demographics:
          {
            ssn: '111222333'
          }
      }.to_json
    }

  end
end