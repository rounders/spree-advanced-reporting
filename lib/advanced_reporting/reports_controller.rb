module AdvancedReporting::ReportsController
  def self.included(target)
    target.class_eval do
      alias :spree_index :index
      def index; advanced_reporting_index; end
    end 
  end

  def advanced_reporting_index
    @reports = {
      :revenue	=> { :name => "Revenue", :description => "Revenue" },
      :units	=> { :name => "Units", :description => "Units" }
    }.merge(Admin::ReportsController::AVAILABLE_REPORTS)
  end

  def get_date_formatting(p)
    date_hash = "%F"
    date_display = "%m-%d-%Y"
    header_display = 'Day'
    if p[:advanced_reporting][:split]
      if p[:advanced_reporting][:split] == 'weekly'
        date_hash = "%U"
        date_display = "%F"
        header_display = 'Week'
      end
      if p[:advanced_reporting][:split] == 'monthly'
        date_hash = "%Y-%m"
        date_display = "%B %Y"
        header_display = 'Month'
      end
    end
    { :date_hash => date_hash, :date_display => date_display, :header_display => header_display }
  end

  def dropdowns
    # Move below to before filter since it'll be run for multiple things
    if defined?(MultiDomainExtension)
      @stores = Store.all
      @products = Product.all 
      # TODO: add class to products dropdown so selecting store will limit products
    else
      @products = Product.all 
    end
  end

  def get_week_display(time)
    d = Date.parse(time.strftime("%F"))
    d -= 1 while Date::DAYNAMES[d.wday] != 'Sunday'
    "#{d.strftime("%m-%d-%Y")} - #{(d+6).strftime("%m-%d-%Y")}"
  end

  def report_setup(report_name) 
    dropdowns
    @dates = get_date_formatting(params)
    @header = @dates[:header_display]
    @results = {}
    @value_total = 0
    @report_name = 'Units'

    @search = Order.searchlogic(params[:search])
    # store id can be an order search param here

    @search.checkout_complete = true
    #set order by to default or form result
    @search.order ||= "descend_by_created_at"

    @orders = @search.find(:all)
  end


  def revenue
    report_setup('Revenue')

    @orders.each do |order|
      date = order.completed_at.strftime(@dates[:date_hash])
      @results[date] ||= {
        :value => 0, 
        :display => params[:advanced_reporting][:split] && params[:advanced_reporting][:split] == 'weekly' ? get_week_display(order.completed_at) : order.completed_at.strftime(@dates[:date_display])
      }
      if params[:advanced_reporting][:product] && params[:advanced_reporting][:product] != ''
        item_rev = order.line_items.select { |li| li.product.id.to_s == params[:advanced_reporting][:product] }.inject(0) { |a, b| a += b.quantity * b.price }
        @results[date][:value] += item_rev
        @value_total += item_rev
      else 
        @results[date][:value] += order.item_total
        @value_total += order.item_total
      end
    end
 
    @results.each { |k, v| @results[k][:value] = "$#{@results[k][:value]}" } #number_to_currency @results[k][:value]
    @value_total = "$#{@value_total.to_s}" # number_to_currency @value_total

    render :template => "admin/reports/base_report"
  end

  def units
    report_setup('Units')

    @orders.each do |order|
      date = order.completed_at.strftime(@dates[:date_hash])
      @results[date] ||= {
        :value => 0, 
        :display => params[:advanced_reporting][:split] && params[:advanced_reporting][:split] == 'weekly' ? get_week_display(order.completed_at) : order.completed_at.strftime(@dates[:date_display])
      }
      if params[:advanced_reporting][:product] && params[:advanced_reporting][:product] != ''
        units = order.line_items.select { |li| li.product.id.to_s == params[:advanced_reporting][:product] }.inject(0) { |a, b| a += b.quantity }
        @results[date][:value] += units
        @value_total += units
      else 
        units = order.line_items.sum(:quantity)
        @results[date][:value] += units
        @value_total += units
      end
    end 

    render :template => "admin/reports/base_report"
  end
end
