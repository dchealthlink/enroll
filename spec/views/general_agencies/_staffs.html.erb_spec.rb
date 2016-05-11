require 'rails_helper'

RSpec.describe "general_agencies/profiles/_staffs.html.erb" do
  let(:staff) { FactoryGirl.create(:general_agency_staff_role).person }
  before :each do
    assign :staffs, [staff] 
    render template: "general_agencies/profiles/_staffs.html.erb" 
  end

  it 'should have title' do
    expect(rendered).to have_selector('h3', text: 'General Agency Staff')
  end

  it 'should show staff info' do
    expect(rendered).to have_selector('a', text: "#{staff.first_name} #{staff.last_name}")
  end
end
