require File.join(Rails.root, "app", "data_migrations", "correct_invalid_benefit_group_assignments_for_employer")
# This rake task is to remove the invalid benefit group assignments for the EE's
# format: RAILS_ENV=production bundle exec rake migrations:correct_invalid_benefit_group_assignments_for_employer fein=521247182
namespace :migrations do
  desc "correcting the invalid benefit group assignments for specific employer"
  CorrectInvalidBenefitGroupAssignmentsForEmployer.define_task :correct_invalid_benefit_group_assignments_for_employer => :environment
end
