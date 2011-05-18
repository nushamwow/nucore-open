require 'spec_helper'

describe StatementRow do

  before :each do
    @user=Factory.create(:user)
    @facility=Factory.create(:facility)
    @account=Factory.create(:nufs_account, :account_users_attributes => [Hash[:user => @user, :created_by => @user, :user_role => 'Owner']])
    @facility_account = @facility.facility_accounts.create(Factory.attributes_for(:facility_account))
    @service=@facility.services.create(Factory.attributes_for(:service, :facility_account_id => @facility_account.id))
    @order=@user.orders.create(Factory.attributes_for(:order, :facility_id => @facility.id, :account_id => @account.id, :created_by => @user.id))
    @order_detail=@order.order_details.create(Factory.attributes_for(:order_detail).update(:product_id => @service.id, :account_id => @account.id))
    @statement=Factory.create(:statement, :facility => @facility, :created_by => @user.id, :account => @account)
  end


  it 'should create' do
    assert_nothing_raised do
      StatementRow.create!(:statement => @statement, :amount => 9.23, :order_detail => @order_detail)
    end
  end


  it { should validate_presence_of :order_detail_id }
  it { should validate_presence_of :statement_id }
  it { should validate_numericality_of :amount }
  
end