require 'spec_helper'

describe TransactionSearch do
  class TransactionSearcher < ApplicationController
    attr_reader :facility, :facilities, :account, :accounts, :account_owners, :products, :order_statuses
    attr_writer :facility, :account
    # give us a way to set the user
    attr_accessor :session_user, :order_details

    include TransactionSearch
    def params
      @params
    end
    def params=(params)
      @params = params
    end

    def all_order_details_with_search
      # everything that needs to be done will be done by the module
    end

  end
  before :each do
    @user = Factory.create(:user)
    @staff = Factory.create(:user, :username => "staff")
    @staff2 = Factory.create(:user, :username => "staff2")
    UserRole.grant(@staff, UserRole::FACILITY_DIRECTOR)
    @controller = TransactionSearcher.new
    @authable         = Factory.create(:facility)
    @facility_account = @authable.facility_accounts.create(Factory.attributes_for(:facility_account))
    @price_group      = @authable.price_groups.create(Factory.attributes_for(:price_group))
    @account          = Factory.create(:nufs_account, :account_users_attributes => [Hash[:user => @staff, :created_by => @staff, :user_role => AccountUser::ACCOUNT_OWNER]])
    @order            = @staff.orders.create(Factory.attributes_for(:order, :created_by => @staff.id, :account => @account, :ordered_at => Time.now))    
    @item             = @authable.items.create(Factory.attributes_for(:item, :facility_account_id => @facility_account.id))
    @order_detail_complete = place_and_complete_item_order(@user, @authable, @account)
    @order_detail_new = place_product_order(@staff, @authable, @item)
    
    # fake signing in as staff
    @controller.session_user = @staff
  end
  
  context "wrapping" do
    it "should responsd to all_order_details" do
      @controller.should respond_to(:all_order_details)
    end
  end
  
  context "field populating" do
    context "with facility" do
      before :each do
        @controller.params = { :facility_id => @authable.url_name }
        @controller.init_current_facility
      end
      it "should populate facility" do
        @controller.all_order_details
        @controller.current_facility.should == @authable
        @controller.facilities.should == [@authable]
      end
      it "should populate accounts" do
        @controller.all_order_details
        @controller.account.should be_nil
        @controller.accounts.should == [@account]
      end
      it 'should populate accounts based off order_details, not orders' do
        @account2 = Factory.create(:nufs_account, :account_users_attributes => [Hash[:user => @staff, :created_by => @staff, :user_role => AccountUser::ACCOUNT_OWNER]])
        Order.all.each { |o| o.update_attributes!(:account => @account) }
        OrderDetail.all.each { |od| od.update_attributes!(:account => @account2)}
        @order.reload.account.should == @account
        @controller.all_order_details
        @controller.accounts.should == [@account2]
      end

      it 'should populate owners based off of order_details, not orders' do
        @account2 = Factory.create(:nufs_account, :account_users_attributes => [Hash[:user => @staff2, :created_by => @staff2, :user_role => AccountUser::ACCOUNT_OWNER]])
        Order.all.each { |o| o.update_attributes!(:account => @account) }
        OrderDetail.all.each { |od| od.update_attributes!(:account => @account2) }
        @order.reload.account.owner.user.should == @staff
        @controller.all_order_details
        @controller.account_owners.should == [@staff2]
      end


      it "should not populate an account for another facility" do
        @facility2 = Factory.create(:facility)
        @account2 = Factory.create(:nufs_account, :account_users_attributes => [Hash[:user => @staff, :created_by => @staff, :user_role => AccountUser::ACCOUNT_OWNER]])

        @controller.all_order_details
        @controller.current_facility.should == @authable
        @controller.account.should be_nil
        @controller.accounts.should == [@account]
      end
      it "should populate order statuses" do
        @controller.all_order_details
        @controller.order_statuses.should contain_all [@os_new, @os_complete]
      end
    end
    
    context "with account" do
      before :each do
        @facility2 = Factory.create(:facility)
        @credit_account = Factory.create(:nufs_account, :facility_id => @facility2.id, :account_users_attributes => [Hash[:user => @staff, :created_by => @staff, :user_role => AccountUser::ACCOUNT_OWNER]])
        @facility_account2 = @facility2.facility_accounts.create(Factory.attributes_for(:facility_account))
        @item2             = @facility2.items.create(Factory.attributes_for(:item, :facility_account_id => @facility_account2.id))
        @order_detail2 = place_and_complete_item_order(@user, @facility2, @credit_account)
      end
      
      it "should pull all facilities for nufs account that have transactions" do
        # @account needs to have an order detail for it to show up
        @order_detail3 = place_and_complete_item_order(@user, @facility2, @account)
        @controller.params = { :account_id => @account.id }
        @controller.init_current_account
        @controller.all_order_details
        @controller.current_facility.should be_nil
        @controller.account.should == @account
        @controller.facilities.should contain_all [@authable, @facility2]
      end
      it "should only have a single facility for credit card" do
        @controller.params = { :account_id => @credit_account.id }
        @controller.init_current_account
        @controller.all_order_details
        @controller.current_facility.should be_nil
        @controller.account.should == @credit_account
        @controller.facilities.should == [@facility2]
      end
    end
    context "account owners" do
      before :each do
        @user2 = Factory.create(:user)
        @user3 = Factory.create(:user)
        @account2 = Factory.create(:nufs_account, :account_users_attributes => [Hash[:user => @user2, :created_by => @user2, :user_role => AccountUser::ACCOUNT_OWNER]])
        # account 2 needs to have an order detail for it to show up
        place_and_complete_item_order(@user2, @authable, @account2)
      end
      it "should populate account owners" do
        @controller.params = { :facility_id => @authable.url_name }
        @controller.init_current_facility
        @controller.all_order_details
        @controller.account_owners.should contain_all [@staff, @user2]
      end
    end
    
    context "products" do
      before :each do
        @facility2 = Factory.create(:facility)
        @instrument = @authable.instruments.create(Factory.attributes_for(:instrument, :facility_account_id => @facility_account.id))
        @service = @authable.services.create(Factory.attributes_for(:service, :facility_account_id => @facility_account.id)) 
        @other_item = @facility2.instruments.create(Factory.attributes_for(:item))
        # each product needs to have an order detail for it to show up
        [@item, @instrument, @service].each do |product|
          place_product_order(@staff, @authable, product, @account)
        end
        
        @controller.params = { :facility_id => @authable.url_name }
        @controller.init_current_facility
        @controller.all_order_details
      end
      it "should populate products" do
        @controller.products.should contain_all [@item, @instrument, @service]
      end
    end
  end

  context "searching" do
    context "order statuses" do
      before :each do   
        @order_detail_complete.order_status.should == @os_complete
        @order_detail_new.order_status.should == @os_new
        @controller.params = { :facility_id => @authable.url_name }
        @controller.init_current_facility
      end
      it 'should return all with no status' do
        @controller.all_order_details
        @controller.order_details.should contain_all [@order_detail_new, @order_detail_complete]
      end
      it 'should return just new' do
        @controller.params.merge!({:order_statuses => [@os_new.id]})
        @controller.all_order_details
        @controller.order_details.should == [@order_detail_new]
      end
      it 'should return just complete' do
        @controller.params.merge!({:order_statuses => [@os_complete.id]})
        @controller.all_order_details
        @controller.order_details.should == [@order_detail_complete]
      end
        
    end
  end

end