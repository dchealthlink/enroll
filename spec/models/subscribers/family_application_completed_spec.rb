require "rails_helper"

describe Subscribers::FamilyApplicationCompleted do
  let(:hbx_profile_organization) { double("HbxProfile", benefit_sponsorship:  double(current_benefit_coverage_period: double(slcsp: Plan.new.id)))}

  it "should subscribe to the correct event" do
    expect(Subscribers::FamilyApplicationCompleted.subscription_details).to eq ["acapi.info.events.family.application_completed"]
  end

  before do
    allow(HbxProfile).to receive(:current_hbx).and_return(hbx_profile_organization)
  end

  after(:all) do
    DatabaseCleaner.clean
  end

  describe "errors logged given a payload" do
    let(:message) { { "body" => xml } }

    context "with valid single member" do
      let(:xml) { File.read(Rails.root.join("spec", "test_data", "verified_family_payloads", "valid_verified_family_sample.xml")) }

      context "with no person matched to user and no primary family associated with the person" do
        it "log both No person and Failed to find primary family errors" do
          expect(subject).to receive(:log) do |arg1, arg2|
            expect(arg1).to match(/No person found for user/)
            expect(arg2).to eq({:severity => 'error'})
          end
          expect(subject).to receive(:log) do |arg1, arg2|
            expect(arg1).to match(/Failed to find primary family for users person/)
            expect(arg2).to eq({:severity => 'error'})
          end
          subject.call(nil, nil, nil, nil, message)
        end
      end

      context "with no person matched to user and no primary family associated with the person" do
        let(:person) { FactoryGirl.create(:person) }

        before do
          allow(Person).to receive(:where).and_return([person])
        end

        it "logs the failed to find primary family error" do
          expect(subject).to receive(:log) do |arg1, arg2|
            expect(arg1).to match(/Failed to find primary family for users person/)
            expect(arg2).to eq({:severity => 'error'})
          end
          subject.call(nil, nil, nil, nil, message)
        end
      end

      context "with a valid single person family" do
        let(:person) { FactoryGirl.create(:person) }
        let(:family) { Family.new.build_from_person(person) }
        let(:consumer_role) { FactoryGirl.create(:consumer_role, person: person) }

        before do
          family.update_attribute(:e_case_id, "curam_landing_for#{person.id}")
          allow(HbxProfile).to receive(:current_hbx).and_return(hbx_profile_organization)
          allow(person).to receive(:consumer_role).and_return(consumer_role)
          allow(Person).to receive(:where).and_return([person])
          allow(Organization).to receive(:where).and_return([hbx_profile_organization])
        end

        after do
          Family.delete_all
        end

        it "shouldn't log any errors the first time" do
          expect(subject).not_to receive(:log)
          subject.call(nil, nil, nil, nil, message)
        end

        context "imports a payload with a different e_case_id/integrated_case_id" do

          it "should log an error saying integrated_case_id does not match family " do
            subject.call(nil, nil, nil, nil, message)
            expect(subject).to receive(:log) do |arg1, arg2|
              expect(arg1).to match(/Integrated case id does not match existing family/)
              expect(arg2).to eq({:severity => 'error'})
            end
            family.update_attribute(:e_case_id, "some_other_id")
            subject.call(nil, nil, nil, nil, message)
          end
        end
      end
    end
  end

  describe "given a valid payload more than once" do
    let(:message) { { "body" => xml } }
    let(:xml) { File.read(Rails.root.join("spec", "test_data", "verified_family_payloads", "valid_verified_family_single_dup_payload_sample.xml")) }
    let(:parser) { Parsers::Xml::Cv::VerifiedFamilyParser.new.parse(File.read(Rails.root.join("spec", "test_data", "verified_family_payloads", "valid_verified_family_single_dup_payload_sample.xml"))).first }
    let(:user) { FactoryGirl.create(:user) }

    context "simulating consumer role controller create action" do
      let(:primary) { parser.family_members.detect{ |fm| fm.id == parser.primary_family_member_id } }
      let(:person) { consumer_role.person }
      let(:ua_params) do
        {
          addresses: [],
          phones: [],
          emails: [],
          person: {
            "first_name" => primary.person.name_first,
            "last_name" => primary.person.name_last,
            "middle_name" => primary.person.name_middle,
            "name_pfx" => primary.person.name_pfx,
            "name_sfx" => primary.person.name_sfx,
            "dob" => primary.person_demographics.birth_date,
            "ssn" => primary.person_demographics.ssn,
            "no_ssn" => "",
            "gender" => primary.person_demographics.sex.split('#').last
          }
        }
      end

      let(:consumer_role) { Factories::EnrollmentFactory.construct_consumer_role(ua_params,user) }

      let(:family_db) { Family.where(e_case_id: parser.integrated_case_id).first }
      let(:tax_household_db) { family_db.active_household.tax_households.first }
      let(:person_db) { family_db.primary_applicant.person }
      let(:consumer_role_db) { person_db.consumer_role }

      it "should not log any errors initially" do
        person.primary_family.update_attribute(:e_case_id, "curam_landing_for#{person.id}")
        expect(subject).not_to receive(:log)
        subject.call(nil, nil, nil, nil, message)
      end

      it "updates the tax household with aptc from the payload on the primary persons family" do
        expect(tax_household_db).to be_truthy
        expect(tax_household_db).to eq person.primary_family.active_household.latest_active_tax_household
        expect(tax_household_db.primary_applicant.family_member.person).to eq person
        expect(tax_household_db.allocated_aptc).to eq 0
        expect(tax_household_db.is_eligibility_determined).to be_truthy
        expect(tax_household_db.current_max_aptc).to eq 269
      end

      it "updates all consumer role verifications" do
        expect(consumer_role_db.fully_verified?).to be_truthy
        expect(consumer_role_db.vlp_authority).to eq "curam"
        expect(consumer_role_db.residency_determined_at).to eq primary.created_at
        expect(consumer_role_db.citizen_status).to eq primary.verifications.citizen_status.split('#').last
        expect(consumer_role_db.is_state_resident).to eq primary.verifications.is_lawfully_present
        expect(consumer_role_db.is_incarcerated).to eq primary.person_demographics.is_incarcerated
      end

      it "updates the address for the primary applicant's person" do
        expect(person_db.addresses).to be_truthy
      end

      it "can recieve duplicate payloads without logging errors" do
        expect(subject).not_to receive(:log)
        subject.call(nil, nil, nil, nil, message)
      end

      it "does should contain both tax households with one of them having an end on date" do
        expect(family_db.active_household.tax_households.length).to eq 2
        expect(family_db.active_household.tax_households.select{|th| th.effective_ending_on.present? }).to be_truthy
      end

      it "maintain the old tax household" do
        expect(tax_household_db).to be_truthy
        expect(tax_household_db.primary_applicant.family_member.person).to eq person
        expect(tax_household_db.allocated_aptc).to eq 0
        expect(tax_household_db.is_eligibility_determined).to be_truthy
        expect(tax_household_db.current_max_aptc).to eq 269
        expect(tax_household_db.effective_ending_on).to be_truthy
      end

      it "should have a new tax household with the same data" do
        updated_tax_household = tax_household_db.household.latest_active_tax_household
        expect(updated_tax_household).to be_truthy
        expect(updated_tax_household.primary_applicant.family_member.person).to eq person
        expect(updated_tax_household.allocated_aptc).to eq 0
        expect(updated_tax_household.is_eligibility_determined).to be_truthy
        expect(updated_tax_household.current_max_aptc).to eq 269
        expect(updated_tax_household.effective_ending_on).not_to be_truthy
      end
    end
  end

  describe "given a valid payload with more multiple members and multiple coverage households" do
    let(:message) { { "body" => xml } }
    let(:xml) { File.read(Rails.root.join("spec", "test_data", "verified_family_payloads", "valid_verified_4_member_family_sample.xml")) }
    let(:user) { FactoryGirl.create(:user) }

    context "simulating consumer role controller create action" do
      let(:parser) { Parsers::Xml::Cv::VerifiedFamilyParser.new.parse(File.read(Rails.root.join("spec", "test_data", "verified_family_payloads", "valid_verified_4_member_family_sample.xml"))).first }
      let(:primary) { parser.family_members.detect{ |fm| fm.id == parser.primary_family_member_id } }
      let(:person) { consumer_role.person }
      let(:ua_params) do
        {
          addresses: [],
          phones: [],
          emails: [],
          person: {
            "first_name" => primary.person.name_first,
            "last_name" => primary.person.name_last,
            "middle_name" => primary.person.name_middle,
            "name_pfx" => primary.person.name_pfx,
            "name_sfx" => primary.person.name_sfx,
            "dob" => primary.person_demographics.birth_date,
            "ssn" => primary.person_demographics.ssn,
            "no_ssn" => "",
            "gender" => primary.person_demographics.sex.split('#').last
          }
        }
      end

      let(:consumer_role) { Factories::EnrollmentFactory.construct_consumer_role(ua_params,user) }

      let(:family_db) { Family.where(e_case_id: parser.integrated_case_id).first }
      let(:tax_household_db) { family_db.active_household.tax_households.first }
      let(:person_db) { family_db.primary_applicant.person }
      let(:consumer_role_db) { person_db.consumer_role }

      it "should not log any errors" do
        person.primary_family.update_attribute(:e_case_id, "curam_landing_for#{person.id}")
        expect(subject).not_to receive(:log)
        subject.call(nil, nil, nil, nil, message)
      end

      it "updates the tax household with aptc from the payload on the primary persons family" do
        expect(tax_household_db).to be_truthy
        expect(tax_household_db).to eq person.primary_family.active_household.latest_active_tax_household
        expect(tax_household_db.primary_applicant.family_member.person).to eq person
        expect(tax_household_db.allocated_aptc).to eq 0
        expect(tax_household_db.is_eligibility_determined).to be_truthy
        expect(tax_household_db.current_max_aptc).to eq 71
      end

      it "has all 4 tax household members with primary person as primary tax household member" do
        expect(tax_household_db.tax_household_members.length).to eq 4
        expect(tax_household_db.tax_household_members.map(&:is_primary_applicant?)).to eq [true,false,false,false]
        expect(tax_household_db.tax_household_members.select{|thm| thm.is_primary_applicant?}.first.family_member).to eq person.primary_family.primary_family_member
      end

      it "has 2 coverage households with 2 members each" do
        expect(tax_household_db.household.coverage_households.length).to eq 2
        expect(tax_household_db.household.coverage_households.first.coverage_household_members.length).to eq 2
        expect(tax_household_db.household.coverage_households.first.coverage_household_members.select{|thm| thm.is_subscriber?}.first.family_member).to eq person.primary_family.primary_family_member
      end

      it "updates all consumer role verifications" do
        expect(consumer_role_db.fully_verified?).to be_truthy
        expect(consumer_role_db.vlp_authority).to eq "curam"
        expect(consumer_role_db.residency_determined_at).to eq primary.created_at
        expect(consumer_role_db.citizen_status).to eq primary.verifications.citizen_status.split('#').last
        expect(consumer_role_db.is_state_resident).to eq primary.verifications.is_lawfully_present
        expect(consumer_role_db.is_incarcerated).to eq primary.person_demographics.is_incarcerated
      end

      it "updates the address for the primary applicant's person" do
        expect(person_db.addresses).to be_truthy
      end
    end
  end
end
