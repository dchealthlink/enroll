require 'rails_helper'
require 'lib/api/v1/support/mobile_ridp_data'

RSpec.describe Api::V1::Mobile::Ridp::RidpVerification, dbclean: :after_each do
  include_context 'ridp_data'
  Mobile = Api::V1::Mobile

  context 'Identity Verification Questions' do

    it 'should return the identity verification questions' do
      ridp = Mobile::Ridp::RidpVerification.new body: question_request_json
      response = JSON.parse ridp.build_question_response.to_json
      expect(response).to be_a_kind_of Hash
      expect(response).to include('verification_result', 'session')

      session = response['session']
      expect(session).to include('response_code', 'transaction_id', 'session_id', 'questions')

      questions = session['questions']
      expect(questions).to be_a_kind_of Array

      question = questions.first
      expect(question).to include('question_id', 'question_text', 'response_options')

      options = question['response_options']
      expect(options).to be_a_kind_of Array

      option = options.first
      expect(option).to include('response_id', 'response_text')
    end

    it 'should return the identity verification final response' do
      ridp = Mobile::Ridp::RidpVerification.new body: answer_request_json
      response = JSON.parse ridp.build_answer_response.to_json
      expect(response).to be_a_kind_of Hash
      expect(response).to include('verification_result', 'session')

      verification_result = response['verification_result']
      expect(verification_result).to include('response_code', 'response_text', 'transaction_id')
    end

  end
end