# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class AdvancedReportingExtension < Spree::Extension
  version "1.0"
  description "Advanced Reporting"
  url "http://www.endpoint.com/"

  def self.require_gems(config)
    config.gem "ruport"
    config.gem "ruport-util", :lib => 'ruport/util'
  end

  def activate
    Admin::ReportsController.send(:include, AdvancedReporting::ReportsController)

    # TODO: Figure out a better place for this?
    Ruport::Controller::Table.formats.merge({ :flot => MyFlotFormatter })

    Ruport::Formatter::HTML.class_eval do
      # Renders individual rows for the table.
      def build_row(data = self.data)
        @odd = !@odd
        klass = @odd ? "odd" : "even"
        output <<
        "\t\t<tr class=\"#{klass}\">\n\t\t\t<td>" +
        data.to_a.join("</td>\n\t\t\t<td>") +
        "</td>\n\t\t</tr>\n"
      end

      def html_table
        @odd = false
        "<table class=\"tablesorter\">\n" << yield << "</table>\n"
      end

      def build_table_header
        output << "\t<table class=\"tablesorter\">\n"
        unless data.column_names.empty? || !options.show_table_headers
          output << "\t\t<thead><tr>\n\t\t\t<th>" + 
            data.column_names.join("</th>\n\t\t\t<th>") + 
            "</th>\n\t\t</tr></thead>\n"
        end
      end
    end
  end
end
