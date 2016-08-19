mespace :export do
  desc "Import Database"
  task :database => :environment do
    cmd = nil
    cmd = "mongodump -d enroll_development -o #{Rails.root}/db/backups"
    puts "Create DB dump"
    exec cmd
  end
end

namespace :restore do
  desc "Restore Database"
  task :database => :environment do
    cmd = nil
    cmd = "mongorestore #{Rails.root}/db/backups/enroll_development --db enroll_development"
    puts "Import saved database"
    exec cmd
  end
end
# Rake::Task['db:mongoid:purge'].invoke

# run => rake export:database
# run => rake restore:database


