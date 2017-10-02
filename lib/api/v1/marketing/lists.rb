# 
# api/marketing/lists provides mailing list data for marketing
# 
# requires the config file config/marketing.yml (see comments therein)
# 
# post params:
#  - user: required, the username
#  - key: required, the api key
#  - q: required, the query, possible values...
#      - employers
#      - brokers
#      - individuals
#      - individuals_no_enrollment
#      - individual_enrollments
#      - brokers_pending
# 
# to make an api key, 'rails r mk_api_key.rb' (random key), or 'rails r mk_api_key.rb my_plain_text' 
# 

class Api::V1::Marketing::Lists

    def initialize (a)
        @caller = a
        require 'pp'
    end

    # 
    # get_list()
    #   
    def get_list
        @app_config = {}
        if File.exists? (Rails.root.to_s + '/config/marketing.yml')
            @app_config = YAML.load_file(Rails.root.to_s + '/config/marketing.yml')[Rails.env]
        end
        @bugger = @app_config['allow_bugger'] && @caller.params['bugger'] != nil ? true : false
        @bugger_out = []

        @new_enrollments_dayspan = 16.days.ago
        @stopwatch = {}
        @stopwatch_start = Time.now
        @stopwatch_seq = 0
        @carrier_to_name = {}
        @plan_id_to_plan_year = {}
        @plan_id_to_plan_name = {}
        @plan_id_to_carrier = {}
        @plan_year = Time.now.year
        @plan_year_fwd = Time.now.month == 11 || Time.now.month == 12 ? Time.now.year + 1 : Time.now.year
        bugger_add('@plan_year: ' + @plan_year.to_s) # bugger
        bugger_add('@plan_year_fwd: ' + @plan_year_fwd.to_s) # bugger

        out = {}
        out[:bugger] = @bugger_out if @bugger
        out[:code] = 0
        out[:message] = 'ok'
        out[:data] = []
        method_ok = false

        bugger_add('ip: ' + @caller.request.remote_ip) # bugger
        bugger_add({'args' => @caller.params.except(:key)}) # bugger
        bugger_add({'key' => @caller.params[:key].length}) if @caller.params[:key] # bugger
        bugger_add({'form method' => @caller.request.method}) # bugger
        ck_stopwatch('start') # bugger
        config_ok = true

        if ! ck_config
            config_ok = false
            out[:code] = 4
            out[:message] = 'configuration error'
        end

        if config_ok
            if @caller.request.get? && @bugger
                method_ok = true 
            elsif @caller.request.post?
                method_ok = true 
            else
                out[:code] = 1
                out[:message] = 'method not allowed'
            end
        end

        if method_ok && config_ok
            if auth
                out[:data] = case @caller.params[:q]
                    when 'employers' then q_employers
                    when 'brokers' then q_brokers
                    when 'individuals' then q_individuals
                    when 'individuals_no_enrollment' then q_individuals_no_enrollment
                    when 'individual_enrollments' then q_individual_enrollments
                    when 'brokers_pending' then q_brokers_pending
                    else 
                        out[:code] = 3
                        out[:message] = 'missing or unknown query parameter'
                        out[:data] = []
                end
            else
                out[:code] = 2
                out[:message] = 'auth fail'
            end
        end

        ck_stopwatch('end') # bugger
        bugger_add({'stopwatch' => @stopwatch}) # bugger
        @caller.render json: out
    end

    # 
    # ck_config()
    #   
    # see if config is there and has all required settings
    #   
    def ck_config
        ok = false
        if @app_config['allow_bugger'] != nil &&
           @app_config['allowed_ips'] != nil && @app_config['allowed_ips'].length > 0 &&
           @app_config['api_user'] != nil &&
           @app_config['api_key'] != nil &&
           @app_config['key_type'] != nil then
            ok = true
        end

        return ok
    end

    # 
    # q_brokers_pending()
    #   
    # brokers who are pending prerequisites and approval
    #   
    def q_brokers_pending
        mlist = []
        bugger_add('q_brokers_pending()...') # bugger
        ck_stopwatch('pre select q_brokers_pending') # bugger

        found = CollPeople.only(:emails, :broker_role, :first_name, :last_name)
            .where(
                "is_active": true,
                "broker_role.provider_kind": { "$in": ["broker", "assister"] },
                :emails.nin => [nil, []]
            )

        bugger_add('found: ' + found.length.to_s) # bugger
        bugger_add(pp found) # bugger
        ck_stopwatch('pre q_brokers_pending loop') # bugger
        # broker_role.aasm_state states: applicant, broker_agency_pending, active, decertified

        found.each do |r|
            if r[:broker_role][:provider_kind] == 'broker' && r[:broker_role][:aasm_state] == 'broker_agency_pending' then
                target = false
                if ! r[:broker_role][:license] || ! r[:broker_role][:training] then
                    target = true
                end

                if ! target && r[:broker_role][:carrier_appointments].keys then
                    r[:broker_role][:carrier_appointments].keys.each do |appointment|
                        if ! r[:broker_role][:carrier_appointments][appointment] then
                            target = true 
                            break
                        end
                    end
                end

                if target then 
                    em = r[:emails].shift
                    tdate = false
                    r[:broker_role][:workflow_state_transitions].each do |tr|
                        if tr[:to_state] == 'broker_agency_pending' then
                            tdate = tr[:transition_at]
                            break
                        end
                    end if r[:broker_role][:workflow_state_transitions]

                    tmp = {
                        :first_name => r[:first_name],
                        :last_name => r[:last_name],
                        :email => em[:address],
                        :active => false,
                        :pending_since => tdate,
                        :market_kind => r[:broker_role][:market_kind],
                        :license => r[:broker_role][:license],
                        :training => r[:broker_role][:training],
                        :appointments => r[:broker_role][:carrier_appointments],
                        :is_broker => false,
                    }
                    mlist.push(tmp)
                end

            # we don't need these anymore, it overlaps the all brokers query
            # elsif r[:broker_role][:aasm_state] == 'active' || r[:broker_role][:aasm_state] == 'decertified' then
            #     em = r[:emails].shift
            #     tmp = {
            #         :first_name => r[:first_name],
            #         :last_name => r[:last_name],
            #         :email => em[:address],
            #         :active => r[:broker_role][:aasm_state],
            #         :pending_since => false,
            #         :provider_kind => r[:broker_role][:provider_kind],
            #         :market_kind => r[:broker_role][:market_kind],
            #         :is_broker => true,
            #     }
            #     mlist.push(tmp)

            end
        end if found

        return mlist
    end

    # 
    # q_employers()
    #   
    # all active employer staff
    #   
    def q_employers
        mlist = []
        bugger_add('q_employers()...') # bugger
        ck_stopwatch('pre select q_employers') # bugger

        found = CollPeople.only(:emails, :first_name, :last_name)
            .where(
                "is_active": true,
                "employer_staff_roles.is_active": true,
                :emails.nin => [nil, []]
            )

        bugger_add('found: ' + found.length.to_s) # bugger
        bugger_add(pp found) # bugger
        ck_stopwatch('pre q_employers loop') # bugger

        found.each do |r|
            em = r[:emails].shift
            tmp = {
                :first_name => r[:first_name],
                :last_name => r[:last_name],
                :email => em[:address],
                :is_employer => true,
            }
            mlist.push(tmp)
        end if found

        return mlist
    end

    # 
    # q_brokers()
    #   
    # all active brokers and assisters
    #   
    def q_brokers
        mlist = []
        bugger_add('q_brokers()...') # bugger
        ck_stopwatch('pre select q_brokers') # bugger

        found = CollPeople.only(:emails, :broker_role, :first_name, :last_name)
            .where(
                "is_active": true,
                "broker_role.provider_kind": { "$in": ["broker", "assister"] },
                :emails.nin => [nil, []]
            )

        bugger_add('found: ' + found.length.to_s) # bugger
        bugger_add(pp found) # bugger
        ck_stopwatch('pre q_brokers loop') # bugger
        # broker_role.aasm_state states: applicant, broker_agency_pending, active, decertified

        found.each do |r|
            if r[:broker_role][:aasm_state] == 'active' then
                em = r[:emails].shift
                tmp = {
                    :first_name => r[:first_name],
                    :last_name => r[:last_name],
                    :email => em[:address],
                    :active => r[:broker_role][:aasm_state],
                    :provider_kind => r[:broker_role][:provider_kind],
                    :market_kind => r[:broker_role][:market_kind],
                    :is_broker => true,
                }
                mlist.push(tmp)
            end
        end if found 

        return mlist
    end

    # 
    # q_individuals_no_enrollment()
    #   
    # individuals who have completed signup but not yet selected a plan
    #   
    def q_individuals_no_enrollment
        ck_stopwatch('pre select enrollments') # bugger
        bugger_add('q_individuals_no_enrollment()...') # bugger

        mlist = []
        q_span_from = 17.days.ago
        q_span_to = 1.days.ago

        users = CollUsers.only(:identity_verified_date, :updated_at, :created_at)
            .where(
                :identity_verified_date.ne => nil,
                :roles => "consumer",
                :created_at => (q_span_from .. q_span_to),
                :identity_verified_date => (q_span_from .. q_span_to)
            )

        bugger_add('users...') # bugger
        bugger_add(pp users) # bugger

        users.each do |u|
            persons = CollPeople.only(:emails, :first_name, :last_name)
                .where(
                    :user_id => u[:_id],
                    :emails.nin => [nil, []]
                )
            bugger_add('person...') # bugger
            bugger_add(pp persons[0]) # bugger

            if persons.length == 1 then # get plans for person_id...
                p = persons.shift
                enr = CollFamilies.only(:family_members, :households)
                    .where(
                        "family_members.person_id" => p[:_id],
                        "family_members.is_coverage_applicant" => true,
                        "households.hbx_enrollments.aasm_state" => "coverage_selected",
                        "households.hbx_enrollments.workflow_state_transitions.to_state" => "coverage_selected"
                    )

                bugger_add('enrollments: ' + enr.length.to_s) # bugger

                if enr.length == 0 then  # there are no plans selected, we have a match...
                    em = p[:emails].shift
                    tmp = {
                        :first_name => p[:first_name],
                        :last_name => p[:last_name],
                        :verify_date => u[:identity_verified_date],
                        :lastmod => u[:updated_at],
                        :created => u[:created_at],
                        :email => em[:address],
                    }
                    mlist.push(tmp)
                    bugger_add('* found match for : ' + em[:address]) # bugger
                end
            end
        end if users

        return mlist
    end

    # 
    # q_individual_enrollments()
    # 
    # individuals who have selected a plan
    # 
    def q_individual_enrollments

        mlist = []
        ck_stopwatch('pre select enrollments') # bugger
        bugger_add('q_individual_enrollments()...') # bugger

        enrollments = CollFamilies.only(:family_members, :households)
            .elem_match(
                'households.hbx_enrollments': {
                    'aasm_state': 'coverage_selected',
                    'kind': 'individual',
                    'submitted_at': (@new_enrollments_dayspan .. Time.now)
                }
            )

        bugger_add('enrollments: ' + enrollments.length.to_s) # bugger
        bugger_add(pp enrollments) # bugger

        load_plan_map() unless enrollments.length == 0

        ck_stopwatch('pre enrollments loop') # bugger
        enrollments.each do |enr|
            enr[:family_members].each do |fm|
                bugger_add('is_primary_applicant=' + fm[:is_primary_applicant].to_s) # bugger
                if fm[:is_primary_applicant] then
                    person = get_person_consumer(fm[:person_id])
                    if person then
                        bugger_add(pp person) # bugger
                        # now get all the other info for plans and create mlist rec...
                        tmp = {}
                        tmp[:first_name] = person[:first_name]
                        tmp[:last_name] = person[:last_name]
                        tmp[:email] = person[:emails][0][:address]

                        plans = []
                        enr[:households].each do |hh|
                            get_selected_coverage(hh[:hbx_enrollments], plans, enr[:family_members])
                        end if enr[:households]

                        bugger_add(pp plans) # bugger
                        tmp[:plans] = plans
                        mlist.push(tmp)
                        break
                    end
                end
            end if enr[:family_members]
        end if enrollments

        return mlist
    end

    # 
    # q_individuals()
    # 
    # all active individuals
    # 
    def q_individuals
        bugger_add('q_individuals()...') # bugger
        out = []
        found = 0

        users = CollUsers.only(:_id)
            .where(
                :identity_verified_date.ne => nil,
                :roles => "consumer"
            ).map(&:_id)
        bugger_add('users...') # bugger
        bugger_add(pp users) # bugger

        recs = CollPeople.only(:first_name, :last_name, :emails)
           .where(:user_id.in => users)
           .where("consumer_role.is_active": true)
           .where(:emails.nin => [nil, []])

        # response time (local): roughly 1s per 10k recs
        # never use!: for i in 0 ... recs.size
        recs.each do |r|
            em = r[:emails].shift
            unless em[:address].blank?
                out.push({
                    :first_name => r[:first_name],
                    :last_name => r[:last_name],
                    :email => em[:address],
                })
                found += 1
            end
        end if recs
        bugger_add({'records_found' => found}) # bugger

        return out
    end

    # 
    # carrier_name_from_plan()
    #   
    def carrier_name_from_plan (plan_id)
        ret = ''
        if @plan_id_to_carrier.key?(plan_id) then
            carrier_id = @plan_id_to_carrier[plan_id]
            if @carrier_to_name.key?(carrier_id) then
                ret = @carrier_to_name[carrier_id]
            end
        end

        return ret
    end

    # 
    # load_plan_map()
    #   
    def load_plan_map
        seen_carrier_ids = {}
        pyr = @plan_year == @plan_year_fwd ? @plan_year : (@plan_year .. @plan_year_fwd)

        plans = CollPlans.only(:carrier_profile_id, :active_year, :name)
           .where('is_active': true, 'active_year': pyr)
           #.where('is_active': true, 'active_year': (@plan_year .. @plan_year_fwd))

           # .where('is_active': true, 'active_year': @plan_year)
           # something: (from .. to_range)

        plans.each do |r|
            @plan_id_to_carrier[r[:_id]] = r[:carrier_profile_id]
            seen_carrier_ids[r[:carrier_profile_id]] = 1
            @plan_id_to_plan_year[r[:_id]] = r['active_year']
            @plan_id_to_plan_name[r[:_id]] = r['name']
        end if plans

        bugger_add('plan_id_to_carrier (' + @plan_id_to_carrier.length.to_s + ')') # bugger
        bugger_add(pp @plan_id_to_carrier) # bugger
        bugger_add(pp plans) # bugger
        bugger_add(pp seen_carrier_ids) # bugger
        bugger_add('@plan_id_to_plan_year: ') # bugger
        bugger_add(pp @plan_id_to_plan_year) # bugger


        orgs = CollOrgs.only(:carrier_profile, :legal_name)
           .where('carrier_profile._id': { '$in': seen_carrier_ids.keys })
           #.where(:carrier_profile.exists => true)

        orgs.each do |r|
            @carrier_to_name[r[:carrier_profile][:_id]] = r[:legal_name]
        end if orgs

        bugger_add('carrier_to_name') # bugger
        bugger_add(pp @carrier_to_name) # bugger
    end

    # 
    # get_selected_coverage()
    #   
    def get_selected_coverage (enrollments, plans, family)
        bugger_add('get_selected_coverage()...') # bugger

        enrollments.each do |enr|
            if enr[:aasm_state] == 'coverage_selected' && 
                    enr[:kind] == 'individual' && 
                    enr[:submitted_at].between?(@new_enrollments_dayspan, Time.now) then
                tmp = {}
                tmp[:id] = enr[:plan_id]
                tmp[:carrier_name] = carrier_name_from_plan(enr[:plan_id])
                tmp[:plan_year] = @plan_id_to_plan_year[enr[:plan_id]]
                tmp[:plan_name] = @plan_id_to_plan_name[enr[:plan_id]]
                tmp[:effective_on] = enr[:effective_on]

                enr[:workflow_state_transitions].each do |wst|
                    if wst[:to_state] == 'coverage_selected' then
                        tmp[:selected_on] = wst[:transition_at]
                    end
                end if enr[:workflow_state_transitions]

                tmp[:type] = enr[:coverage_kind]

                # per legal: this is not provided in mail lists
                # tmp[:members] = get_enrolled_members(enr, family)

                # see: app/models/hbx_enrollment.rb
                # per legal: premium is not provided in mail lists
                # hbx_enrollment = HbxEnrollment.find(enr[:_id])
                # bugger_add('hbx_enrollment...') # bugger
                # bugger_add(pp hbx_enrollment) # bugger
                # if ! hbx_enrollment.nil? then # add our amount due field...
                #     tmp[:total_premium] = hbx_enrollment.total_premium.to_s # some kind of on-demand caluation method?
                #     bugger_add('hbx_enrollment.total_premium: ' + tmp[:total_premium]) # bugger
                # end

                plans.push(tmp)
            end
        end if enrollments
    end

    # 
    # get_enrolled_members()
    #   
    def get_enrolled_members (enr, family)
        bugger_add('get_enrolled_members()...') # bugger
        persons = []
        person_ids = []
        family_map = {}

        family.each do |fm|
            family_map[fm[:_id]] = fm[:person_id]
        end if family

        enr[:hbx_enrollment_members].each do |m|
            person_ids.push(family_map[m[:applicant_id]])
        end if enr[:hbx_enrollment_members]

        p = CollPeople.only(:first_name).where("_id": { '$in': person_ids })

        p.each do |person|
            persons.push(person[:first_name])
        end if p

        return persons
    end

    # 
    # get_person_consumer()
    #   
    def get_person_consumer (id)
        bugger_add('get_person(' + id + ')...') # bugger

        p = CollPeople.only(:first_name, :last_name, :emails, :consumer_role)
           .where("_id": id)
           .where("consumer_role.is_active": true)
           .where(:emails.nin => [nil, []])

        return p.length > 0 ? p[0] : false 
    end

    # 
    # ck_api_key()
    #   
    def ck_api_key (user, key, type)
        ok = false
        user_ok = @caller.params['user'] == user ? true : false
        bugger_add('ck_api_key()...') # bugger
        if (@caller.params['user'] == user)
            bugger_add(' user: ok') # bugger
            if (type == 'plain' && @caller.params['key'] == key)
                ok = true
                bugger_add(' key (plain): ok') # bugger
            elsif (type == 'hashed' && ck_hash(@caller.params['key'], key))
                ok = true
                bugger_add(' key (hashed): ok') # bugger
            else
                bugger_add(' key: fail') # bugger
            end
        else
            bugger_add(' user: fail') # bugger
        end

        return ok
    end

    # 
    # ck_hash()
    #   
    def ck_hash (plain, hashed)
        ok = false
        require 'bcrypt'
        hashed_pass = BCrypt::Password.new(hashed)
        ok = true if hashed_pass == plain

        return ok
    end

    # 
    # auth()
    #   
    def auth
        ok = false
        ip_ok = false

        bugger_add('auth()...') # bugger
        bugger_add('found key: allowed_ips') if @app_config['allowed_ips'] # bugger
        bugger_add({'@app_config' => @app_config}) # bugger

        # if ! @app_config['allowed_ips'] 
        #     ip_ok = true
        # elsif @app_config['allowed_ips'].include? @caller.request.remote_ip
        if @app_config['allowed_ips'].include? @caller.request.remote_ip
            ip_ok = true
        end

        if ip_ok
            if ck_api_key(@app_config['api_user'], @app_config['api_key'], @app_config['key_type'])
                @caller.logger.info @caller.params['controller'] + ' auth ok ' + @caller.request.remote_ip
                ok = true
            else
                @caller.logger.warn @caller.params['controller'] + ' api key fail ' + @caller.request.remote_ip
                bugger_add('api key fail') # bugger
            end
        else
            @caller.logger.warn @caller.params['controller'] + ' connect from unauthorized ip address ' + 
                @caller.request.remote_ip
            bugger_add('ip not allowed') # bugger
        end

        return ok
    end

    # 
    # ck_stopwatch()
    #   
    def ck_stopwatch (x)
        @stopwatch_seq += 1
        @stopwatch[@stopwatch_seq.to_s.rjust(3, '0') + ' ' + x] = Time.now - @stopwatch_start # bugger
    end

    # 
    # bugger_add()
    #   
    def bugger_add (x)
        @bugger_out.push(x) if @bugger
    end

    # 
    # CollUsers: mongoid model
    #   
    class CollUsers
        include Mongoid::Document
        store_in collection: 'users'
    end

    # 
    # CollOrgs: mongoid model
    #   
    class CollOrgs
        include Mongoid::Document
        store_in collection: 'organizations'
    end

    # 
    # CollPlans: mongoid model
    #   
    class CollPlans
        include Mongoid::Document
        store_in collection: 'plans'
    end

    # 
    # CollPeople: mongoid model
    #   
    class CollPeople
        include Mongoid::Document
        store_in collection: 'people'
        field :first_name, type: String
        field :last_name, type: String
    end

    # 
    # CollFamilies: mongoid model
    #   
    class CollFamilies
        include Mongoid::Document
        store_in collection: 'families'
    end
end

