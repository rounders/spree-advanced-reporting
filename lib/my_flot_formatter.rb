# This formatter implements the CSV format for Ruport's Row, Table, Group
# and Grouping controllers.  It is a light wrapper around
# James Edward Gray II's FasterCSV.
# === Rendering Options
# <tt>:style</tt> Used for grouping (:inline,:justified,:raw)      
# <tt>:format_options</tt> A hash of FasterCSV options  
# <tt>:formatter</tt> An existing FasterCSV object to write to
# <tt>:show_table_headers</tt> True by default
# <tt>:show_group_headers</tt> True by default
#
class MyFlotFormatter < Ruport::Formatter
  
  renders :flot, :for => [ Ruport::Controller::Row,   Ruport::Controller::Table, 
                          Ruport::Controller::Group, Ruport::Controller::Grouping ]
  
  # Hook for setting available options using a template. See the template 
  # documentation for the available options and their format.
  def apply_template
    apply_table_format_template(template.table)
    apply_grouping_format_template(template.grouping)
  end

  # Generates table header by turning column_names into a CSV row.
  # Uses the row controller to generate the actual formatted output
  #
  # This method does not do anything if options.show_table_headers is false
  # or the Data::Table has no column names.
  def build_table_header
    output << "[\n"
  end

  def build_table_footer
    output << "\n]"
  end

  # Calls the row controller for each row in the Data::Table
  def build_table_body
    data.each_with_index do |row, index|
      output << "[\"" + data.column_names.inject([]) { |a, c| a.push(row[c]); a }.join('","') + "\"]"
      output << ",\n" if data.size != index + 1
    end
  end

  # Renders the header for a group using the group name.
  # 
  def build_group_header
    output << "" #<p>#{data.name}</p>"
  end
  
  # Renders the group body - uses the table controller to generate the output.
  #
  def build_group_body
    render_table data, options.to_hash
  end
  
  # Generates a header for the grouping using the grouped_by column and the
  # column names.
  #
  def build_grouping_header
    unless options.style == :inline
      output << [data.grouped_by] + grouping_columns
    end
  end
 
  # Determines the proper style to use and renders the Grouping.
  def build_grouping_body
    case options.style
    when :inline
      render_inline_grouping(options)
    when :justified, :raw
      render_justified_or_raw_grouping
    else
      raise NotImplementedError, "Unknown style"
    end
  end
  
  private
  
  def grouping_columns
    data.data.to_a[0][1].column_names
  end
  
  def render_justified_or_raw_grouping
    data.each do |_,group|
      prefix = [group.name.to_s]
      group.each do |row|
        output << prefix + row.to_a
        prefix = [nil] if options.style == :justified
      end
      output << []
    end
  end
  
  def apply_table_format_template(t)
    t = (t || {}).merge(options.table_format || {})
    options.show_table_headers = t[:show_headings] if
      options.show_table_headers.nil?
  end
  
  def apply_grouping_format_template(t)
    t = (t || {}).merge(options.grouping_format || {})
    options.style ||= t[:style]
    options.show_group_headers = t[:show_headings] if
      options.show_group_headers.nil?
  end
  
end
