class Api::V1::Marketing::ListsController < ActionController::Base # instead of < ApplicationController to skip devise auth

    # 
    # list(): the controller method for api/marketing/lists
    #   
    def get_list
        require 'api/v1/marketing/lists'
        listh = Api::V1::Marketing::Lists.new(self)
        listh.get_list
    end
end
