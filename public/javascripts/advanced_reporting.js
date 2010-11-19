$(function() {
	$('table.show_data td').click(function() {
		$('table.show_data td').not(this).removeClass('selected');
		$(this).addClass('selected');
		var id = 'div#' + $(this).attr('id') + '_data';
		$('div.advanced_reporting_data').not($(id)).hide();
		$(id).show();
	});
	$('table.tablesorter').tablesorter();

	if($('.map').length > 0) {
		$('.map').maphilight({ "stroke" : false, "fillOpacity" : "0.0" });
	}
	$(['daily', 'weekly', 'monthly']).each(function(i, f) {
		if($('div#flotter_' + f).length > 0) {
			$.plot($('#flotter_' + f), flot_data['weekly']);
		}
	});
})
