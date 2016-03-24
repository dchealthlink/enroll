FactoryGirl.define do
  factory :user do
    sequence(:email) {|n| "example\##{n}@example.com"}
    gen_pass = User.generate_valid_password
    password gen_pass
    password_confirmation gen_pass
    sequence(:authentication_token) {|n| "j#{n}-#{n}DwiJY4XwSnmywdMW"}
    approved true
    roles ['web_service']
  end

  trait :without_email do
    email ' '
  end

  trait :without_password do
    password ' '
  end

  trait :without_password_confirmation do
    password_confirmation ' '
  end

  trait :hbx_staff do
    roles ["hbx_staff"]
  end

  trait :consumer do
    roles ["consumer"]
  end

  trait "assister" do
    roles ["assister"]
  end

  trait "csr" do
    roles ["csr"]
  end

  trait "employee" do
    roles ["employee"]
  end

  trait :employer_staff do
    roles ["employer_staff"]
  end

  trait :broker do
    roles ["broker"]

    ignore do
      organization {}
    end

    after :create do |user, evaluator|
      if user.person.present?
        user.person.broker_agency_staff_roles.push FactoryGirl.build(:broker_agency_staff_role, broker_agency_profile_id: evaluator.organization.broker_agency_profile.id)
        evaluator.organization.broker_agency_profile.primary_broker_role = FactoryGirl.create :broker_role, person: user.person, broker_agency_profile: evaluator.organization.broker_agency_profile
        evaluator.organization.save
        user.save
      end
    end
  end

  trait "broker_agency_staff" do
    roles ["broker_agency_staff"]
  end

  trait :with_family do
    after :create do |user|
      FactoryGirl.create :person, :with_family, :user => user
    end
  end

  factory :invalid_user, traits: [:without_email, :without_password, :without_password_confirmation]
end
