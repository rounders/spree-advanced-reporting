$(function() {
  $('table.show_data td').click(function() {
    $('table.show_data td').not(this).removeClass('selected');
    $(this).addClass('selected');
    var id = 'div#' + $(this).attr('id') + '_data';
    $('div.advanced_reporting_data').not($(id)).hide();
    $(id).show();
  });
  $('table.tablesorter').tablesorter();
})
