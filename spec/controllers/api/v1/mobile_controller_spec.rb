require 'rails_helper'
require 'support/brady_bunch'
require 'lib/api/v1/support/mobile_broker_data'
require 'lib/api/v1/support/mobile_broker_agency_data'
require 'lib/api/v1/support/mobile_individual_data'
require 'lib/api/v1/support/mobile_ridp_data'

RSpec.describe Api::V1::MobileController, dbclean: :after_each do
  include_context 'broker_agency_data'

  describe "GET employers_list" do

    it "should get summaries for employers where broker_agency_account is active" do
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      xhr :get, :broker, broker_agency_profile_id: broker_agency_profile.id, format: :json
      expect(response).to have_http_status(:success), "expected status 200, got #{response.status}: \n----\n#{response.body}\n\n"
      details = JSON.parse(response.body)['broker_clients']
      detail = JSON.generate(details[0])
      detail = JSON.parse(detail, :symbolize_names => true)
      expect(details.count).to eq 1
      expect(detail[:employer_name]).to eq employer_profile.legal_name
      contacts = detail[:contact_info]

      seymour = contacts.detect { |c| c[:first] == 'Seymour' }
      beatrice = contacts.detect { |c| c[:first] == 'Beatrice' }
      office = contacts.detect { |c| c[:first] == 'Primary' }
      expect(seymour[:mobile]).to eq '(202) 555-0000'
      expect(seymour[:phone]).to eq ''
      expect(beatrice[:phone]).to eq '(202) 555-0001'
      expect(beatrice[:mobile]).to eq '(202) 555-0002'
      expect(seymour[:emails]).to include('seymour@example.com')
      expect(beatrice[:emails]).to include('beatrice@example.com')
      expect(office[:phone]).to eq '(202) 555-9999'
      expect(office[:address_1]).to eq '500 Employers-Api Avenue'
      expect(office[:address_2]).to eq '#555'
      expect(office[:city]).to eq 'Washington'
      expect(office[:state]).to eq 'DC'
      expect(office[:zip]).to eq '20001'

      output = JSON.parse(response.body)

      expect(output["broker_name"]).to eq("Brunhilde")
      employer = output["broker_clients"][0]
      expect(employer).not_to be(nil), "in #{output}"
      expect(employer["employer_name"]).to eq(employer_profile.legal_name)
      expect(employer["employees_total"]).to eq(employer_profile.roster_size)
      expect(employer["employer_details_url"]).to end_with("mobile/employers/#{employer_profile.id}/details")
    end
  end

  describe "GET employer_details" do
    let(:user) { double("user", :person => person) }
    let(:person) { double("person", :employer_staff_roles => [employer_staff_role]) }
    let(:employer_staff_role) { double(:employer_profile_id => employer_profile.id) }
    let!(:plan_year) { FactoryGirl.create(:plan_year, aasm_state: "published") }
    let!(:benefit_group) { FactoryGirl.create(:benefit_group, :with_valid_dental, plan_year: plan_year, title: "Test Benefit Group") }
    let!(:employer_profile) { plan_year.employer_profile }
    let!(:employee1) { FactoryGirl.create(:census_employee, employer_profile_id: employer_profile.id) }
    let!(:employee2) { FactoryGirl.create(:census_employee, :with_enrolled_census_employee, employer_profile_id: employer_profile.id) }

    before(:each) do
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      sign_in(user)
    end

    it 'should render 200 with valid ID' do
      get :employer_details, {employer_profile_id: employer_profile.id.to_s}
      expect(response).to have_http_status(200), "expected status 200, got #{response.status}: \n----\n#{response.body}\n\n"
      expect(response.content_type).to eq 'application/json'
    end

    it "should render 404 with Invalid ID" do
      get :employer_details, {employer_profile_id: "Invalid Id"}
      expect(response).to have_http_status(404), "expected status 404, got #{response.status}: \n----\n#{response.body}\n\n"
    end

    it "should match with the expected result set" do
      get :employer_details, {employer_profile_id: employer_profile.id.to_s}
      output = JSON.parse(response.body)
      expect(output["employer_name"]).to eq(employer_profile.legal_name)
      expect(output["employees_total"]).to eq(employer_profile.roster_size)
      expect(output["active_general_agency"]).to eq(employer_profile.active_general_agency_legal_name)
    end
  end

  context "Test functionality and security of Mobile API controller actions" do
    include_context 'BradyWorkAfterAll'
    include_context 'BradyBunch'

    before :each do
      create_brady_census_families
      carols_plan_year.update_attributes(aasm_state: "published") if carols_plan_year.aasm_state != "published"
    end

    #Mikes specs begin
    context "Mike's broker" do
      include_context 'broker_data'

      before(:each) do
        sign_in mikes_broker
        get :broker, format: :json
        @output = JSON.parse(response.body)
        mikes_plan_year.update_attributes(aasm_state: "published") if mikes_plan_year.aasm_state != "published"
      end

      it "should be able to login and get success status" do
        expect(@output["broker_name"]).to eq("John")
        expect(response).to have_http_status(:success), "expected status 200, got #{response.status}: \n----\n#{response.body}\n\n"
      end

      it "should have 1 client in their broker's employer's list" do
        expect(@output["broker_clients"].count).to eq 1
      end

      it "should be able to see only Mikes Company in the list and it shouldn't be nil" do
        expect(@output["broker_clients"][0]).not_to be(nil), "in #{@output}"
        expect(@output["broker_clients"][0]["employer_name"]).to eq(mikes_employer_profile.legal_name)
      end

      it "should be able to access Mike's employee roster" do
        get :employee_roster, {employer_profile_id: mikes_employer_profile.id.to_s}, format: :json
        @output = JSON.parse(response.body)
        expect(response).to have_http_status(:success)
        expect(@output["employer_name"]).to eq(mikes_employer_profile.legal_name)
        expect(@output["roster"].blank?).to be_falsey
      end

      it "should be able to access Mike's employer details" do
        expect(mikes_employer_profile.plan_years.count).to be > 0

        get :employer_details, {employer_profile_id: mikes_employer_profile.id.to_s}, format: :json
        @output = JSON.parse(response.body)

        expect(response).to have_http_status(:success)
        expect(@output["employer_name"]).to eq "Mike's Architects Limited"
        expect(@output["employees_total"]).to eq 1
        expect(@output["binder_payment_due"]).to eq ""
        expect(@output["active_general_agency"]).to be(nil)
        plan_year = @output["plan_years"].detect do |py|
          py["plan_year_begins"] == mikes_employer_profile.active_plan_year.start_on.strftime("%Y-%m-%d")
        end
        expect(plan_year).to_not be nil
        expect(plan_year["open_enrollment_begins"]).to eq mikes_employer_profile.active_plan_year.open_enrollment_start_on.strftime("%Y-%m-%d")
        expect(plan_year["open_enrollment_ends"]).to eq mikes_employer_profile.active_plan_year.open_enrollment_end_on.strftime("%Y-%m-%d")
        expect(plan_year["renewal_in_progress"]).to be_falsey
        expect(Date.parse(plan_year["renewal_application_available"])).to be < mikes_employer_profile.active_plan_year.start_on
        expect(plan_year["renewal_application_due"]).to eq mikes_plan_year.due_date_for_publish.strftime("%Y-%m-%d")
        expect(plan_year["minimum_participation_required"]).to eq 1
        expect(plan_year["plan_offerings"].size).to eq 1
      end

      it "should not be able to access Carol's broker's employer list" do
        get :broker, {broker_agency_profile_id: carols_broker_agency_profile.id}, format: :json
        expect(response).to have_http_status(404)
      end

      it "should not be able to access Carol's employee roster" do
        get :employee_roster, {employer_profile_id: carols_employer_profile.id.to_s}, format: :json
        expect(response).to have_http_status(404)
      end

      it "should not be able to access Carol's employer details" do
        get :employer_details, {employer_profile_id: carols_employer_profile.id.to_s}, format: :json
        expect(response).to have_http_status(404)
      end
    end

    context "Mikes employer specs" do
      include_context 'broker_data'

      before(:each) do
        sign_in mikes_employer_profile_user
      end

      it "Mikes employer shouldn't be able to see the employers_list and should get 404 status on request" do
        get :broker, broker_agency_profile_id: mikes_broker_agency_profile.id, format: :json
        @output = JSON.parse(response.body)
        expect(response.status).to eq 404
      end

      it "Mikes employer should be able to see his own roster" do
        get :employee_roster, {employer_profile_id: mikes_employer_profile.id.to_s}, format: :json
        @output = JSON.parse(response.body)
        expect(response).to have_http_status(:success)
        expect(@output["employer_name"]).to eq(mikes_employer_profile.legal_name)
        expect(@output["roster"].blank?).to be_falsey
      end

      it "Mikes employer should render 200 with valid ID" do
        get :employer_details, {employer_profile_id: mikes_employer_profile.id.to_s}, format: :json
        @output = JSON.parse(response.body)
        expect(response).to have_http_status(200), "expected status 200, got #{response.status}: \n----\n#{response.body}\n\n"
        expect(response.content_type).to eq "application/json"
      end

      it "Mikes employer should render 404 with Invalid ID" do
        get :employer_details, {employer_profile_id: "Invalid Id"}
        expect(response).to have_http_status(404), "expected status 404, got #{response.status}: \n----\n#{response.body}\n\n"
      end

      it "Mikes employer details request should match with the expected result set" do
        get :employer_details, {employer_profile_id: mikes_employer_profile.id.to_s}
        output = JSON.parse(response.body)
        expect(output["employer_name"]).to eq(mikes_employer_profile.legal_name)
        expect(output["employees_total"]).to eq(mikes_employer_profile.roster_size)
        expect(output["active_general_agency"]).to eq(mikes_employer_profile.active_general_agency_legal_name)
      end
    end

    #Carols spec begin
    context "Carols broker specs" do
      include_context 'broker_data'

      before(:each) do
        sign_in carols_broker
        get :broker, format: :json
        @output = JSON.parse(response.body)
      end

      it "Carols broker should be able to login and get success status" do
        expect(@output["broker_name"]).to eq("Walter")
        expect(response).to have_http_status(:success), "expected status 200, got #{response.status}: \n----\n#{response.body}\n\n"
      end

      it "No of broker clients in Carols broker's employer's list should be 1" do
        expect(@output["broker_clients"].count).to eq 1
      end

      it "Carols broker should be able to see only carols Company and it shouldn't be nil" do
        expect(@output["broker_clients"][0]).not_to be(nil), "in #{@output}"
        expect(@output["broker_clients"][0]["employer_name"]).to eq(carols_employer_profile.legal_name)
      end

      it "Carols broker should be able to access Carol's employee roster" do
        get :employee_roster, {employer_profile_id: carols_employer_profile.id.to_s}, format: :json
        @output = JSON.parse(response.body)
        expect(response).to have_http_status(:success)
        expect(@output["employer_name"]).to eq(carols_employer_profile.legal_name)
        expect(@output["roster"]).not_to be []
        expect(@output["roster"].count).to eq 1
      end
    end

    context "Carols employer" do
      include_context 'broker_data'

      before(:each) do
        sign_in carols_employer_profile_user
      end

      it "shouldn't be able to see the employers_list and should get 404 status on request" do
        get :broker, broker_agency_profile_id: carols_broker_agency_profile.id, format: :json
        @output = JSON.parse(response.body)
        expect(response).to have_http_status(:not_found)
      end

      it "should be able to see their own roster specifying id" do
        get :employee_roster, {employer_profile_id: carols_employer_profile.id.to_s}, format: :json
        @output = JSON.parse(response.body)
        expect(response).to have_http_status(:success)
        expect(response.content_type).to eq "application/json"
        expect(@output["employer_name"]).to eq(carols_employer_profile.legal_name)
        expect(@output["roster"].blank?).to be_falsey
      end

      it "should be able to see their own roster by default (with no id)" do
        get :my_employee_roster, format: :json
        @output = JSON.parse(response.body)
        expect(response).to have_http_status(:success)
        expect(response.content_type).to eq "application/json"
        expect(@output["employer_name"]).to eq(carols_employer_profile.legal_name)
        expect(@output["roster"].blank?).to be_falsey
        expect(@output["roster"].first).to include('first_name', 'middle_name', 'last_name', 'date_of_birth', 'ssn_masked',
                                                   'is_business_owner', 'hired_on', 'enrollments')
      end

      it "should be able to see their own employer details by default (with no id)" do
        get :my_employer_details, format: :json
        @output = JSON.parse(response.body)
        expect(response).to have_http_status(:success)
        expect(response.content_type).to eq "application/json"
        expect(@output["employer_name"]).to eq(carols_employer_profile.legal_name)
        expect(@output["employees_total"]).to eq 1
        expect(@output["plan_years"].first).to include('open_enrollment_begins', 'open_enrollment_ends', 'plan_year_begins',
                                                       'renewal_in_progress', 'renewal_application_available', 'renewal_application_due',
                                                       'state', 'minimum_participation_required', 'plan_offerings')
      end

      it "should not be able to see Mike's employer's roster" do
        get :employee_roster, {employer_profile_id: mikes_employer_profile.id.to_s}, format: :json
        @output = JSON.parse(response.body)
        expect(response).to have_http_status(:not_found)
      end

      it "should get 404 NOT FOUND seeking an invalid employer profile ID" do
        get :employer_details, {employer_profile_id: "Invalid Id"}
        expect(response).to have_http_status(404), "expected status 404, got #{response.status}: \n----\n#{response.body}\n\n"
      end

      it "details request should match with the expected result set" do
        get :employer_details, {employer_profile_id: carols_employer_profile.id.to_s}
        output = JSON.parse(response.body)
        expect(output["employer_name"]).to eq(carols_employer_profile.legal_name)
        expect(output["employees_total"]).to eq(carols_employer_profile.roster_size)
        expect(output["active_general_agency"]).to eq(carols_employer_profile.active_general_agency_legal_name)
      end
    end

    context "HBX admin specs" do
      include_context 'broker_data'

      it "HBX Admin should be able to see Mikes details" do
        sign_in hbx_user
        get :broker, broker_agency_profile_id: mikes_broker_agency_profile.id, format: :json
        @output = JSON.parse(response.body)
        expect(@output["broker_agency"]).to eq("Turner Agency, Inc")
        expect(@output["broker_clients"].count).to eq 1
        expect(@output["broker_clients"][0]["employer_name"]).to eq(mikes_employer_profile.legal_name)
      end

      it "HBX Admin should be able to see Carols details" do
        sign_in hbx_user
        get :broker, broker_agency_profile_id: carols_broker_agency_profile.id, format: :json
        @output = JSON.parse(response.body)
        expect(@output["broker_agency"]).to eq("Alphabet Agency")
        expect(@output["broker_clients"].count).to eq 1
        expect(@output["broker_clients"][0]["employer_name"]).to eq(carols_employer_profile.legal_name)
      end
    end
  end

  context "Routes: /individual, /individuals/:id" do
    include_context 'BradyWorkAfterAll'
    include_context 'BradyBunch'

    before :each do
      create_brady_census_families
    end

    context "Mike's Broker" do
      include_context 'broker_data'
      include_context 'individual_data'

      let!(:person_with_family) { FactoryGirl.create(:person, :with_family) }

      it 'should return individual details of user (/individuals/:person_id)' do
        sign_in hbx_user
        get :insured_person, person_id: person_with_family.id, format: :json
        output = JSON.parse response.body
        expect(output).to include('first_name', 'middle_name', 'last_name', 'name_suffix', 'date_of_birth', 'ssn_masked',
                                  'gender', 'id', 'employments')
      end

      it 'should return individual details of user (/individual)' do
        sign_in non_employee_individual_person.user
        get :insured, format: :json
        output = JSON.parse response.body
        expect(output).to include('first_name', 'middle_name', 'last_name', 'name_suffix', 'date_of_birth', 'ssn_masked',
                                  'gender', 'id', 'employments')
      end

      it 'should not return individual details of user it does not have access to' do
        sign_in mikes_broker
        get :insured_person, person_id: carols_broker_role.person.id, format: :json
        output = JSON.parse response.body
        expect(response).to have_http_status(404)
        expect(output['error']).to eq 'no individual details found'
      end

      it 'should not return individual details of user (/individuals/:person_id)' do
        sign_in mikes_broker
        get :insured_person, person_id: mikes_employer_profile_person.id, format: :json
        output = JSON.parse response.body
        expect(response).to have_http_status(404)
        expect(output['error']).to eq 'no individual details found'
      end
    end

  end

  describe "GET services_rates" do
    let(:qhp1) { Products::QhpCostShareVariance.new(hios_plan_and_variant_id: '11111100001111-01') }
    let(:qhp2) { Products::QhpCostShareVariance.new(hios_plan_and_variant_id: '11111100001111-02') }
    let(:service_type) { 'Primary Care Visit to Treat an Injury or Illness' }
    let(:copay) { '$20.00' }
    let(:coinsurance) { 'Not Applicable' }
    let(:service_visits) { [
      Products::QhpServiceVisit.new(
        visit_type: service_type,
        copay_in_network_tier_1: copay,
        co_insurance_in_network_tier_1: coinsurance)
    ] }

    it 'should return an Unprocessable Entity error when all params are not passed' do
      get :services_rates, format: :json
      output = JSON.parse response.body
      expect(response).to have_http_status(422)
      expect(output).to be_a_kind_of Hash
      expect(output['error']).to eq Api::V1::Mobile::Renderer::ServiceRenderer::PARAMETERS_MISSING
    end

    it 'should return the services rates' do
      allow(Products::QhpCostShareVariance).to receive(:find_qhp_cost_share_variances).and_return([qhp1, qhp2])
      allow(qhp1).to receive(:qhp_service_visits).and_return(service_visits)
      allow(qhp2).to receive(:qhp_service_visits).and_return(service_visits)

      get :services_rates, hios_id: '11111100001111-01', active_year: '2015', coverage_kind: 'health', format: :json
      output = JSON.parse response.body
      expect(response).to have_http_status(200)
      expect(output).to be_a_kind_of Array
      service_rate = output.first
      expect(service_rate).to be_a_kind_of Hash
      expect(service_rate).to include('service', 'copay', 'coinsurance')
      expect(service_rate['service']).to eq service_type
      expect(service_rate['copay']).to eq copay
      expect(service_rate['coinsurance']).to eq coinsurance
    end

  end

  describe "GET plans" do
    it 'should return all the plans' do
      get :plans
      output = JSON.parse response.body
      expect(response).to have_http_status(200)
      expect(output).to be_a_kind_of Array
    end
  end

  context 'Routes: /verify_identity & /verify_identity/answers' do
    include_context 'ridp_data'

    describe 'POST verify_identity' do
      it 'should return the identity verification questions' do
        post :verify_identity, question_request_json
        output = JSON.parse response.body
        expect(response).to have_http_status(200)
        expect(output).to be_a_kind_of Hash
      end
    end

    it 'should return the identity verification questions' do
      post :verify_identity_answers, answer_request_json
      output = JSON.parse response.body
      expect(response).to have_http_status(200)
      expect(output).to be_a_kind_of Hash
    end
  end

end