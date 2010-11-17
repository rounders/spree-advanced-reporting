module AdvancedReporting::ReportsController
  def self.included(target)
    target.class_eval do
      alias :spree_index :index
      def index; advanced_reporting_index; end
    end 
  end

  def advanced_reporting_index
    @reports = {
      :revenue		=> { :name => "Revenue", :description => "Revenue" },
      :units		=> { :name => "Units", :description => "Units" },
      :top_products	=> { :name => "Top Products", :description => "Top Products" },
      :top_customers	=> { :name => "Top Customers", :description => "Top Customers" },
      :geo_revenue	=> { :name => "Geo Revenue", :description => "Geo Revenue" },
    }.merge(Admin::ReportsController::AVAILABLE_REPORTS)
  end

  def get_date_formatting
    {
      :daily => {
        :date_hash => "%F",
        :date_display => "%m-%d-%Y",
        :header_display => 'Day'
      },
      :weekly => {
        :date_hash => "%U",
        :date_display => "%F",
        :header_display => 'Week'
      },
      :monthly => {
        :date_hash => "%Y-%m",
        :date_display => "%B %Y",
        :header_display => 'Month'
      }
    }
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
    @dates = get_date_formatting
    @header = 'blah' #@dates ? @dates[:header_display] : '-'
    @value_total = 0
    @report_name = report_name

    @search = Order.searchlogic(params[:search])
    # store id can be an order search param here

    @search.checkout_complete = true
    #set order by to default or form result
    @search.order ||= "descend_by_created_at"

    @orders = @search.find(:all)

    @data = {
      :daily => Table(%w[key display value]),
      :weekly => Table(%w[key display value]),
      :monthly => Table(%w[key display value]),
    } 

    {
      :daily => {},
      :weekly => {},
      :monthly => {}
    }
  end

  def get_revenue(results, dates, orders)
    orders.each do |order|
      date = {}
      [:daily, :weekly, :monthly].each do |type|
        date[type] = order.completed_at.strftime(dates[type][:date_hash])
        results[type][date[type]] ||= {
          :value => 0, 
          :display => type == :weekly ? get_week_display(order.completed_at) : order.completed_at.strftime(dates[type][:date_display])
        }
      end
      if params[:advanced_reporting] && params[:advanced_reporting][:product] && params[:advanced_reporting][:product] != ''
        item_rev = order.line_items.select { |li| li.product.id.to_s == params[:advanced_reporting][:product] }.inject(0) { |a, b| a += b.quantity * b.price }
        [:daily, :weekly, :monthly].each { |type| results[type][date[type]][:value] += item_rev }
        @value_total += item_rev
      else 
        [:daily, :weekly, :monthly].each { |type| results[type][date[type]][:value] += order.item_total }
        @value_total += order.item_total
      end
    end

    [:daily, :weekly, :monthly].each do |type|
      results[type].each do |k,v|
        @data[type] << { "key" => k, "display" => v[:display], "value" => v[:value] } 
      end
    end
  end

  def revenue
    results = report_setup('Revenue')
    get_revenue(results, @dates, @orders)

    # add rendering for different format requests
    respond_to do |format|
      format.html { render :template => "admin/reports/base_report" }
      format.pdf do
        #blah = [:daily, :weekly, :monthly].inject('') { |blah, type| blah += @data[type].to_pdf } 
        #send_data blah, :type =>"application/pdf", :filename => "blah.pdf"
      end
      format.csv do
        send_data @data[:weekly].to_csv, :type =>"application/csv", :filename => "blah.csv"
      end
    end
  end

  def get_units(results, dates, orders)
    orders.each do |order|
      date = {}
      [:daily, :weekly, :monthly].each do |type|
        date[type] = order.completed_at.strftime(dates[type][:date_hash])
        results[type][date[type]] ||= {
          :value => 0, 
          :display => type == :weekly ? get_week_display(order.completed_at) : order.completed_at.strftime(dates[type][:date_display])
        }
      end
      units = order.line_items.sum(:quantity)
      if params[:advanced_reporting] && params[:advanced_reporting][:product] && params[:advanced_reporting][:product] != ''
        units = order.line_items.select { |li| li.product.id.to_s == params[:advanced_reporting][:product] }.inject(0) { |a, b| a += b.quantity }
      end
      [:daily, :weekly, :monthly].each { |type| results[type][date[type]][:value] += units }
      @value_total += units
    end

    [:daily, :weekly, :monthly].each do |type|
      results[type].each do |k,v|
        @data[type] << { "key" => k, "display" => v[:display], "value" => v[:value] } 
      end
    end
  end
  def units
    results = report_setup('Units')
    get_units(results, @dates, @orders)
    # add rendering for different format requests
    render :template => "admin/reports/base_report"
  end

  def top_products
    report_setup("Top Products")    

    results = {}
    @orders.each do |order|
      order.line_items.each do |li|
        if !li.product.nil?
          results[li.product.id] ||= {
            :name => li.product.name.to_s,
            :revenue => 0,
            :units => 0
          }
          results[li.product.id][:revenue] += li.quantity*li.price 
          results[li.product.id][:units] += li.quantity
        end
      end
    end

    sort_results = {}
    results.each do |k, v|
      sort_results[k] = v[:revenue]
    end
    @data = Table(%w[name units revenue])
    sort_results.sort { |a, b| a[1] <=> b [1] }.reverse[0..4].each do |k, v|
      @data << { "name" => results[k][:name], "units" => results[k][:units], "revenue" => results[k][:revenue] } 
    end

    # format revenue column
    render :template => "admin/reports/base_top_report"
  end

  def top_customers
    report_setup("Top Customers")

    results = {}
    @orders.each do |order|
      if order.user
        results[order.user.id] ||= {
          :email => order.user.email,
          :revenue => 0,
          :units => 0
        }
        # check this
        rev = order.item_total
        units = order.line_items.sum(:quantity)
        if params[:advanced_reporting] && params[:advanced_reporting][:product] && params[:advanced_reporting][:product] != ''
          rev = order.line_items.select { |li| li.product.id.to_s == params[:advanced_reporting][:product] }.inject(0) { |a, b| a += b.quantity * b.price }
          units = order.line_items.select { |li| li.product.id.to_s == params[:advanced_reporting][:product] }.inject(0) { |a, b| a += b.quantity }
        end
        results[order.user.id][:revenue] += rev
        results[order.user.id][:units] += units
      end
    end

    @data = Table(%w[email units revenue])
    sort_results = {}
    results.each do |k, v|
      sort_results[k] = v[:revenue]
    end
    sort_results.sort { |a, b| a[1] <=> b [1] }.reverse[0..4].each do |k, v|
      @data << { "email" => results[k][:email], "units" => results[k][:units], "revenue" => results[k][:revenue] } 
    end

    # format revenue column
    render :template => "admin/reports/base_top_report"
  end

  def geo_revenue
    report_setup('Units')
    #get_units(results, @dates, @orders)

    results = {
      :state => {},
      :country => {}
    }
    @orders.each do |order|
      rev = order.item_total
      units = order.line_items.sum(:quantity)
      if params[:advanced_reporting] && params[:advanced_reporting][:product] && params[:advanced_reporting][:product] != ''
        rev = order.line_items.select { |li| li.product.id.to_s == params[:advanced_reporting][:product] }.inject(0) { |a, b| a += b.quantity * b.price }
        units = order.line_items.select { |li| li.product.id.to_s == params[:advanced_reporting][:product] }.inject(0) { |a, b| a += b.quantity }
      end
      if order.bill_address.state
        results[:state][order.bill_address.state_id] ||= {
          :name => order.bill_address.state.name,
          :revenue => 0,
          :units => 0
        }
        results[:state][order.bill_address.state_id][:revenue] += rev
        results[:state][order.bill_address.state_id][:units] += units
      end
      if order.bill_address.country
        results[:country][order.bill_address.country_id] ||= {
          :name => order.bill_address.country.name,
          :revenue => 0,
          :units => 0
        }
        results[:country][order.bill_address.country_id][:revenue] += rev
        results[:country][order.bill_address.country_id][:units] += units
      end
    end

    @data_states = Table(%w[name units revenue])
    results[:state].each do |k, v|
      @data_states << { "name" => v[:name], "units" => v[:units], "revenue" => v[:revenue] } 
    end
    @data_countries = Table(%w[name units revenue])
    results[:country].each do |k, v|
      @data_countries << { "name" => v[:name], "units" => v[:units], "revenue" => v[:revenue] } 
    end
  end
end
