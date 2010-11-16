# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class AdvancedReportingExtension < Spree::Extension
  version "1.0"
  description "Advanced Reporting"
  url "http://www.endpoint.com/"

  def activate
    Admin::ReportsController.send(:include, AdvancedReporting::ReportsController)
  end
end
