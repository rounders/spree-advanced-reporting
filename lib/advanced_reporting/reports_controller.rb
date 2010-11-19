module AdvancedReporting::ReportsController
  def self.included(target)
    target.class_eval do
      alias :spree_index :index
      def index; advanced_reporting_index; end
      before_filter :basic_report_setup, :actions => [:revenue, :units, :top_products, :top_customers, :geo_revenue]
    end 
  end
  ADVANCED_REPORTS = {
      :revenue		=> { :name => "Revenue", :description => "Revenue" },
      :units		=> { :name => "Units", :description => "Units" },
      :top_products	=> { :name => "Top Products", :description => "Top Products" },
      :top_customers	=> { :name => "Top Customers", :description => "Top Customers" },
      :geo_revenue	=> { :name => "Geo Revenue", :description => "Geo Revenue" },
  }

  def advanced_reporting_index
    @reports = ADVANCED_REPORTS.merge(Admin::ReportsController::AVAILABLE_REPORTS)
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
  def get_prior_sunday(time)
    d = Date.parse(time.strftime("%F"))
    d -= 1 while Date::DAYNAMES[d.wday] != 'Sunday'
    d.to_time.to_i
  end

  def basic_report_setup
    @reports = ADVANCED_REPORTS
    dropdowns
    @value_total = 0
    @report_name = params[:action].gsub(/_/, ' ').split(' ').each { |w| w.capitalize! }.join(' ')

    @search = Order.searchlogic(params[:search])
    # store id can be an order search param here
    @search.checkout_complete = true

    @orders = @search.find(:all)
    if params[:advanced_reporting] && params[:advanced_reporting][:product_id] && params[:advanced_reporting][:product_id] != ''
      product = Product.find(params[:advanced_reporting][:product_id])
      @product_text = "Product: #{product.name}<br />" if product
    end
    @date_text = "Date Range:"
    if params[:search]
      if params[:search][:created_at_after] != '' && params[:search][:created_at_before] != ''
        @date_text += " From #{params[:search][:created_at_after]} to #{params[:search][:created_at_before]}"
      elsif params[:search][:created_at_after] != ''
        @date_text += " After #{params[:search][:created_at_after]}"
      elsif params[:search][:created_at_before] != ''
        @date_text += " Before #{params[:search][:created_at_after]}"
      else
        @date_text += " All"
      end
    else
      @date_text += " All"
    end
  end

  def report_increment_setup
    @flot_data = {}
    @data = {}
    [:daily, :weekly, :monthly].each do |type|
      @data[type] = Table(%w[key display value])
      @flot_data[type] = Table(%w[timestamp value])
    end

    @dates = {
      :daily => {
        :date_hash => "%F",
        :date_display => "%m-%d-%Y",
        :header_display => 'Day',
        :timestamp => "%Y-%m-%d"
      },
      :weekly => {
        :date_hash => "%U",
        :date_display => "%F",
        :header_display => 'Week'
      },
      :monthly => {
        :date_hash => "%Y-%m",
        :date_display => "%B %Y",
        :header_display => 'Month',
        :timestamp => "%Y-%m-01"
      }
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
          :display => type == :weekly ? get_week_display(order.completed_at) : order.completed_at.strftime(dates[type][:date_display]),
          :timestamp => type == :weekly ? get_prior_sunday(order.completed_at).to_i :
             Time.parse(order.completed_at.strftime(dates[type][:timestamp])).to_i
        }
      end
      rev = order.item_total
      if params[:advanced_reporting] && params[:advanced_reporting][:product_id] && params[:advanced_reporting][:product_id] != ''
        rev = order.line_items.select { |li| li.product.id.to_s == params[:advanced_reporting][:product_id] }.inject(0) { |a, b| a += b.quantity * b.price }
      end
      [:daily, :weekly, :monthly].each { |type| results[type][date[type]][:value] += rev }
      @value_total += rev
    end

    [:daily, :weekly, :monthly].each do |type|
      results[type].each do |k,v|
        @data[type] << { "key" => k, "display" => v[:display], "value" => v[:value] } 
        @flot_data[type] << { "timestamp" => v[:timestamp], "value" => v[:value] }
      end
      @data[type].sort_rows_by!(["key"])
      @data[type].remove_column("key")
      @data[type].replace_column("value") { |r| "$%0.2f" % r.value }
      @data[type].rename_column("value", "Revenue")
      @data[type].rename_column("display", @dates[type][:header_display])
    end

  end

  def revenue
    results = report_increment_setup
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
          :display => type == :weekly ? get_week_display(order.completed_at) : order.completed_at.strftime(dates[type][:date_display]),
          :timestamp => type == :weekly ? get_prior_sunday(order.completed_at).to_i :
             Time.parse(order.completed_at.strftime(dates[type][:timestamp])).to_i
        }
      end
      units = order.line_items.sum(:quantity)
      if params[:advanced_reporting] && params[:advanced_reporting][:product_id] && params[:advanced_reporting][:product_id] != ''
        units = order.line_items.select { |li| li.product.id.to_s == params[:advanced_reporting][:product_id] }.inject(0) { |a, b| a += b.quantity }
      end
      [:daily, :weekly, :monthly].each { |type| results[type][date[type]][:value] += units }
      @value_total += units
    end

    [:daily, :weekly, :monthly].each do |type|
      results[type].each do |k,v|
        @data[type] << { "key" => k, "display" => v[:display], "value" => v[:value] } 
        @flot_data[type] << { "timestamp" => v[:timestamp], "value" => v[:value] }
      end
      @data[type].sort_rows_by!(["key"])
      @data[type].remove_column("key")
      @data[type].rename_column("value", "Units")
      @data[type].rename_column("display", @dates[type][:header_display])
    end
  end
  def units
    results = report_increment_setup
    get_units(results, @dates, @orders)
    # add rendering for different format requests
    render :template => "admin/reports/base_report"
  end

  def top_products
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

    @data = Table(%w[name Units Revenue])
    results.inject({}) { |h, (k, v) | h[k] = v[:revenue]; h }.sort { |a, b| a[1] <=> b [1] }.reverse[0..4].each do |k, v|
      @data << { "name" => results[k][:name], "Units" => results[k][:units], "Revenue" => results[k][:revenue] } 
    end
    @data.replace_column("Revenue") { |r| "$%0.2f" % r.Revenue }
    @data.rename_column("name", "Product Name")

    # format revenue column
    render :template => "admin/reports/base_top_report"
  end

  def top_customers
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
        if params[:advanced_reporting] && params[:advanced_reporting][:product_id] && params[:advanced_reporting][:product_id] != ''
          rev = order.line_items.select { |li| li.product.id.to_s == params[:advanced_reporting][:product_id] }.inject(0) { |a, b| a += b.quantity * b.price }
          units = order.line_items.select { |li| li.product.id.to_s == params[:advanced_reporting][:product_id] }.inject(0) { |a, b| a += b.quantity }
        end
        results[order.user.id][:revenue] += rev
        results[order.user.id][:units] += units
      end
    end

    @data = Table(%w[email Units Revenue])
    results.inject({}) { |h, (k, v) | h[k] = v[:revenue]; h }.sort { |a, b| a[1] <=> b [1] }.reverse[0..4].each do |k, v|
      @data << { "email" => results[k][:email], "Units" => results[k][:units], "Revenue" => results[k][:revenue] } 
    end
    @data.replace_column("Revenue") { |r| "$%0.2f" % r.Revenue }
    @data.rename_column("email", "Customer Email")

    # format revenue column
    render :template => "admin/reports/base_top_report"
  end

  def geo_revenue
    results = {
      :state => {},
      :country => {}
    }
    @orders.each do |order|
      rev = order.item_total
      units = order.line_items.sum(:quantity)
      if params[:advanced_reporting] && params[:advanced_reporting][:product_id] && params[:advanced_reporting][:product_id] != ''
        rev = order.line_items.select { |li| li.product.id.to_s == params[:advanced_reporting][:product_id] }.inject(0) { |a, b| a += b.quantity * b.price }
        units = order.line_items.select { |li| li.product.id.to_s == params[:advanced_reporting][:product_id] }.inject(0) { |a, b| a += b.quantity }
      end
      if order.bill_address.state
        results[:state][order.bill_address.state_id] ||= {
          :name => order.bill_address.state.name,
          :revenue => 0,
          :units => 0,
          :abbr => order.bill_address.state.abbr
        }
        results[:state][order.bill_address.state_id][:revenue] += rev
        results[:state][order.bill_address.state_id][:units] += units
      end
      if order.bill_address.country
        results[:country][order.bill_address.country_id] ||= {
          :name => order.bill_address.country.name,
          :revenue => 0,
          :units => 0,
          :iso => order.bill_address.country.iso
        }
        results[:country][order.bill_address.country_id][:revenue] += rev
        results[:country][order.bill_address.country_id][:units] += units
      end
    end

    @data = {}
    [:state, :country].each do |type|
      @data[type] = Table(%w[location Units Revenue])
      results[type].each do |k, v|
        @data[type] << { "location" => v[:name], "Units" => v[:units], "Revenue" => v[:revenue] } 
      end
      @data[type].sort_rows_by!(["location"])
      @data[type].rename_column("location", type.to_s.capitalize)
      @data[type].replace_column("Revenue") { |r| "$%0.2f" % r.Revenue }
    end

    @map_data = {}
    max = {}
    [:state, :country].each do |type|
      max[type] = results[type].inject({}) { |h, (k, v)| h[k] = v[:revenue]; h }.values.max
      if max[type] > 0
        key = type == :state ? :abbr : :iso
        @map_data[type] = results[type].inject({}) { |h, (k, v)| h[v[key]] = { :opacity => opacity(v[:revenue], max[type]), :value => v[:revenue] }; h }
      end
    end

    @geomaps = { :state => Geomap.find_by_permalink('usa'), :country => Geomap.find_by_permalink('world') }
  end

  def opacity(value, max)
    "%02.f" % (value.to_f/(1.5*max)*100).to_i
  end
end
