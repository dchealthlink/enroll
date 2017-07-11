# bundle exec rspec --format documentation spec/controllers/api/v1/marketing/lists_controller_spec.rb 

require 'rails_helper'

RSpec.describe Api::V1::Marketing::ListsController do

    # 
    # initialize()
    # 
    def initialize (x)
        @base_earl = 'api/marketing/lists?'
        @bugger = false
    end

    # 
    # show_test()
    # 
    def show_test (t, p)
        puts ''
        puts '  trying ' + @base_earl + p.to_query
        puts '    [' + t + ']'
    end

    # 
    # show_subtest()
    # 
    def show_subtest (message, result = true)
        printf "    %-80s %s\n", message, (result ? '[OK]' : '*** FAILED ***')
    end

    # 
    # bugger_add()
    # 
    def bugger_add (message)
        pp message if @bugger
    end

    # 
    # describe
    # 
    describe 'GET get_list' do

        # get with no params (code 1, method not allowed)
        t1 = 'get with no params (code 1, method not allowed)'
        it t1 do
            params = {}
            get 'get_list'
            show_test t1, params
            json = JSON.parse(response.body)
            expect(response).to be_success
            show_subtest 'response be_success'
            expect(response).to have_http_status(200)
            show_subtest 'have_http_status 200'
            bugger_add json # bugger
            expect(json['code']).to be == 1
            show_subtest 'code == ' + json['code'].to_s
            show_subtest 'message == ' + json['message']
        end

        # get with bugger and no auth (code 2, auth fail)
        t2 = 'get with bugger and no auth (code 2, auth fail)'
        it t2 do
            params = {
                'bugger' => 1,
            }
            get 'get_list', params
            show_test t2, params
            json = JSON.parse(response.body)
            bugger_add json # bugger
            expect(json['code']).to be == 2
            show_subtest 'code == ' + json['code'].to_s
            show_subtest 'message == ' + json['message']
            show_subtest 'bugger[2] == ' + json['bugger'][2]
            expect(json['bugger'][2]).to be == 'ip: 0.0.0.0'
        end

        # post with user and bad key (code 2, auth fail)
        t3 = 'post with user and bad key (code 2, auth fail)'
        it t3 do
            params = {
                'key' => 'xxxxxxxxx',
                'user' => 'emma',
            }
            post 'get_list', params
            show_test t3, params
            json = JSON.parse(response.body)
            bugger_add json # bugger
            expect(json['code']).to be == 2
            show_subtest 'code == ' + json['code'].to_s
            show_subtest 'message == ' + json['message']
        end

        # post with bad user and key (code 2, auth fail)
        t4 = 'post with bad user and key (code 2, auth fail)'
        it t4 do
            params = {
                'key' => '2b0fde9309034dc07de88a6a52be1bb81a5501a4bb329f3ada929296971b72d5',
                'user' => 'xxxxxxx',
            }
            post 'get_list', params
            show_test t4, params
            json = JSON.parse(response.body)
            bugger_add json # bugger
            expect(json['code']).to be == 2
            show_subtest 'code == ' + json['code'].to_s
            show_subtest 'message == ' + json['message']
        end

        # post with auth but no query (code 3, missing or unknown query parameter)
        t5 = 'post with auth but no query (code 3, missing or unknown query parameter)'
        it t5 do
            params = {
                'key' => '2b0fde9309034dc07de88a6a52be1bb81a5501a4bb329f3ada929296971b72d5',
                'user' => 'emma',
            }
            post 'get_list', params
            show_test t5, params
            json = JSON.parse(response.body)
            bugger_add json # bugger
            expect(json['code']).to be == 3
            show_subtest 'code == ' + json['code'].to_s
            show_subtest 'message == ' + json['message']
        end

        # bad config (code 4), can't test this
        t6 = 'bad config (code 4), can\'t test this'
        it t6 do
            params = {}
            show_test t6, params
            show_subtest 'skipped'
            expect(1).to be == 1
        end

        # query employers
        t7 = 'query employers'
        it t7 do
            params = {
                'key' => '2b0fde9309034dc07de88a6a52be1bb81a5501a4bb329f3ada929296971b72d5',
                'user' => 'emma',
                'q' => 'employers',
            }
            post 'get_list', params
            show_test t7, params
            json = JSON.parse(response.body)
            bugger_add json # bugger
            expect(json['code']).to be == 0
            show_subtest 'code == ' + json['code'].to_s
            show_subtest 'message == ' + json['message']
            show_subtest 'data.length == ' + json['data'].length.to_s
            expect(json['data']).to be_an_instance_of(Array)
        end

        # query brokers
        t8 = 'query brokers'
        it t8 do
            params = {
                'key' => '2b0fde9309034dc07de88a6a52be1bb81a5501a4bb329f3ada929296971b72d5',
                'user' => 'emma',
                'q' => 'brokers',
            }
            post 'get_list', params
            show_test t8, params
            json = JSON.parse(response.body)
            bugger_add json # bugger
            expect(json['code']).to be == 0
            show_subtest 'code == ' + json['code'].to_s
            show_subtest 'message == ' + json['message']
            show_subtest 'data.length == ' + json['data'].length.to_s
            expect(json['data']).to be_an_instance_of(Array)
        end

        # query individuals
        t9 = 'query individuals'
        it t9 do
            params = {
                'key' => '2b0fde9309034dc07de88a6a52be1bb81a5501a4bb329f3ada929296971b72d5',
                'user' => 'emma',
                'q' => 'individuals',
            }
            post 'get_list', params
            show_test t9, params
            json = JSON.parse(response.body)
            bugger_add json # bugger
            expect(json['code']).to be == 0
            show_subtest 'code == ' + json['code'].to_s
            show_subtest 'message == ' + json['message']
            show_subtest 'data.length == ' + json['data'].length.to_s
            expect(json['data']).to be_an_instance_of(Array)
        end

        # query individuals_no_enrollment
        t10 = 'query individuals_no_enrollment'
        it t10 do
            params = {
                'key' => '2b0fde9309034dc07de88a6a52be1bb81a5501a4bb329f3ada929296971b72d5',
                'user' => 'emma',
                'q' => 'individuals_no_enrollment',
            }
            post 'get_list', params
            show_test t10, params
            json = JSON.parse(response.body)
            bugger_add json # bugger
            expect(json['code']).to be == 0
            show_subtest 'code == ' + json['code'].to_s
            show_subtest 'message == ' + json['message']
            show_subtest 'data.length == ' + json['data'].length.to_s
            expect(json['data']).to be_an_instance_of(Array)
        end

        # query individual_enrollments 
        t11 = 'query individual_enrollments'
        it t11 do
            params = {
                'key' => '2b0fde9309034dc07de88a6a52be1bb81a5501a4bb329f3ada929296971b72d5',
                'user' => 'emma',
                'q' => 'individual_enrollments',
            }
            post 'get_list', params
            show_test t11, params
            json = JSON.parse(response.body)
            bugger_add json # bugger
            expect(json['code']).to be == 0
            show_subtest 'code == ' + json['code'].to_s
            show_subtest 'message == ' + json['message']
            show_subtest 'data.length == ' + json['data'].length.to_s
            expect(json['data']).to be_an_instance_of(Array)
        end

        # query brokers_pending 
        t12 = 'query brokers_pending'
        it t12 do
            params = {
                'key' => '2b0fde9309034dc07de88a6a52be1bb81a5501a4bb329f3ada929296971b72d5',
                'user' => 'emma',
                'q' => 'brokers_pending',
            }
            post 'get_list', params
            show_test t12, params
            json = JSON.parse(response.body)
            bugger_add json # bugger
            expect(json['code']).to be == 0
            show_subtest 'code == ' + json['code'].to_s
            show_subtest 'message == ' + json['message']
            show_subtest 'data.length == ' + json['data'].length.to_s
            expect(json['data']).to be_an_instance_of(Array)
        end

    end
end

