class ItemPricePolicy < PricePolicy

  validates_numericality_of :unit_cost, :unless => :restrict_purchase
  validate :subsidy_less_than_rate?, :unless => lambda { |pp| pp.unit_cost.nil? || pp.unit_subsidy.nil? }

  scope :current,  lambda { |product|             { :conditions => [dateize('start_date', ' = ? AND product_id = ?'), current_date(product), product.id] } }
  scope :next,     lambda { |product|             { :conditions => [dateize('start_date', ' = ? AND product_id = ?'), next_date(product), product.id] } }
  scope :for_date, lambda { |product, start_date| { :conditions => [dateize('start_date', ' = ? AND product_id = ?'), start_date, product.id] } }

  before_save { |o| o.unit_subsidy = 0 if o.unit_subsidy.nil? && !o.unit_cost.nil? }

  def self.current_date(product)
    ipp = product.price_policies.find(:first, :conditions => [dateize('start_date', ' <= ? AND ') + dateize('expire_date', ' > ?'), Time.zone.now, Time.zone.now], :order => 'start_date DESC')
    ipp ? ipp.start_date.to_date : nil
  end

  def self.next_date(product)
    ipp = nil
    product.price_policies.sort{|p1,p2| p1.start_date <=> p2.start_date}.each{|pp| ipp=pp and break if pp.start_date > Time.zone.now}
    ipp ? ipp.start_date.to_date : nil
  end

  def self.next_dates(product)
    ipps = []

    product.price_policies.each do |pp|
      sdate=pp.start_date
      ipps << sdate.to_date if sdate > Time.zone.now && !ipps.include?(sdate)
    end

    ipps.uniq
  end

  def subsidy_less_than_rate?
    errors.add("unit_subsidy", "cannot be greater than the Unit cost") if (unit_subsidy > unit_cost)
  end

  def calculate_cost_and_subsidy (qty = 1)
    estimate_cost_and_subsidy(qty)
  end

  def estimate_cost_and_subsidy(qty = 1)
    return nil if restrict_purchase?
    costs = {}
    costs[:cost]    = unit_cost * qty
    costs[:subsidy] = unit_subsidy * qty
    costs
  end

  def unit_total
    unit_cost - unit_subsidy
  end

end
