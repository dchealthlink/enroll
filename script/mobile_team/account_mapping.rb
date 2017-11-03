def assign_test_account_to_email(email, login, password)
    old_user = User.where(oim_id: /^#{login}$/i).first
    if old_user 
        old_email = old_user.person ? old_user.person.work_email_or_best : "<no person>"
        print "Found previous user account  #{old_user.oim_id} (#{old_email}), archiving it\n"
        old_user.oim_id = "was_#{login}_#{Date.today.ld}"
        if old_user.save
            print "archived old user\n"
        else
            print "problem archiving old user: #{old_user.errors.messages}"
        end
    else
        print "No previous user #{login} found\n"
    end
    u = User.where(email: /^#{email}$/i).first
    if u  
        u.oim_id = login
        u.password = password
        if u.save
            print "assigned #{login} to #{email}\n"
        else 
            print "Problems: #{u.errors.messages}"
        end
   else
        print "No user found with email #{email}\n"
   end
end

def assign_test_account_to_employer(employer_legal_name, login, password)
    employer_profile = Organization.where(legal_name: /#{employer_legal_name}/i).first.employer_profile
    print "Assigning #{employer_profile.organization.legal_name} login #{login} and password #{password}\n"
    er = Person.where(:employer_staff_roles => { 
        '$elemMatch' => { 
            employer_profile_id: {"$in": [employer_profile.id] },
            :aasm_state.ne => :is_closed}}).detect{|p| p.work_email_or_best}
    abort "No staff member with a valid email found\n" unless er   
    print "Found employer staff member #{er.full_name} (#{er.work_email_or_best}), assigning new login/pwd\n"
    
    assign_test_account_to_email er.work_email_or_best, login, password
end

 


