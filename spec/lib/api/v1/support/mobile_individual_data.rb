module MobileIndividualData
  shared_context 'individual_data' do
    let(:user) { FactoryGirl.create(:user) }
    let(:user2) { FactoryGirl.create(:user) }
    let(:employer_profile) { FactoryGirl.create(:employer_profile) }
    let(:employee_role) { FactoryGirl.create(:employee_role, census_employee_id: census_employee.id,
                                             employer_profile_id: employer_profile.id) }
    let(:broker_agency_profile) { FactoryGirl.create(:broker_agency_profile) }
    let(:broker_agency_staff_role) { FactoryGirl.create(:broker_agency_staff_role) }
    let(:census_employee) { FactoryGirl.create(:census_employee, employer_profile: employer_profile) }
    let(:benefit_group_assignment) { FactoryGirl.create(:benefit_group_assignment, census_employee: census_employee) }
    let(:census_dependent) { FactoryGirl.create(:census_dependent, census_employee: census_employee) }
    let!(:shop_family) { FactoryGirl.create(:family, :with_primary_family_member) }
    let (:benefit_group) { FactoryGirl.create(:benefit_group, title: 'Everyone') }
    let!(:calendar_year) { TimeKeeper.date_of_record.year }
    let!(:effective_date) { Date.new(calendar_year, 1, 1) }
    let(:hbx_enrollment) {
      FactoryGirl.create(:hbx_enrollment,
                         household: shop_family.latest_household,
                         coverage_kind: :health,
                         effective_on: effective_date,
                         enrollment_kind: 'open_enrollment',
                         kind: 'employer_sponsored',
                         submitted_at: effective_date - 10.days,
                         benefit_group_id: benefit_group.id,
                         employee_role_id: employee_role.id,
                         benefit_group_assignment_id: benefit_group_assignment.id,
                         aasm_state: 'coverage_enrolled')
    }
    let!(:person) { FactoryGirl.create(:person_with_employee_role, ssn: 123456789, user: user, employer_profile_id: employer_profile.id,
                                      hired_on: census_employee.hired_on, census_employee_id: census_employee.id) }
    let(:another_person) { FactoryGirl.create(:person_with_employee_role, :with_family, ssn: 223456789, user: user2, employer_profile_id: employer_profile.id,
                                              hired_on: census_employee.hired_on, census_employee_id: census_employee.id) }
    let!(:non_employee_individual_person) { FactoryGirl.create(:person, :with_consumer_role, ssn: 243456789, user: user2) }
    let!(:family) { FactoryGirl.create(:family, :with_primary_family_member, person: non_employee_individual_person) }
    let!(:family_member) {FactoryGirl.create(:family_member, family: family)}
    let!(:household) { FactoryGirl.create(:household, family: family) }
    let!(:consumer_role) { FactoryGirl.create(:consumer_role, person: non_employee_individual_person, is_applicant: true) }
    let!(:hbx_enrollment_individual_health) {
      FactoryGirl.create(
          :hbx_enrollment,
          household: household,
          coverage_kind: :health,
          kind: 'individual',
          is_active: true,
          aasm_state: 'coverage_enrolled',
          changing: false,
          consumer_role_id: consumer_role.id,
          effective_on: (TimeKeeper.date_of_record.beginning_of_month + 10.days))
    }
    let!(:hbx_enrollment_individual_dental) {
      FactoryGirl.create(
          :hbx_enrollment,
          household: household,
          coverage_kind: :dental,
          kind: 'individual',
          is_active: true,
          aasm_state: 'coverage_enrolled',
          changing: false,
          consumer_role_id: consumer_role.id,
          effective_on: (TimeKeeper.date_of_record.beginning_of_month + 10.days))
    }
  end
end