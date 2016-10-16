DT = ( function() {
  var clear_level = function(level) {
    level_str = String(level)
    $('.custom_level_' + level_str).addClass("hide")
    $('.custom_level_' + level_str+ ' .btn-default').removeClass("clicked")
    if (level < 4) {
      clear_level(level + 1)
    }
  }
  var hide_lower_levels = function(button) {
    level = 0
    var button_group = $(button).parent()
    var button_group_class = button_group.attr('class')
    var get_level_regex = /custom_level_(\d)/
    var get_level = get_level_regex.exec(button_group_class)
    var level = parseInt(get_level && get_level[1])
    console.log(level)
    clear_level(level+1)
  }
  var filters= function(){
    $('.custom_level_1').removeClass('hide')
    $('.custom_filter .btn-default').click(function() {
      var that = this
      hide_lower_levels(that)
      if ($(that).hasClass('clicked')) {
        console.log('unclick')
        $(that).removeClass('clicked')
        return
      }
      $(that.parentElement.children).removeClass('clicked')
      $(that).addClass('clicked')
      id = $(that).attr('id').substring(4).replace(/\//g,'-')
      //window.id = id
      //alert('hi')
      $('.Filter-'+id).removeClass('hide')
    })
   extendDatatableServerParams = function(){
    var keys = {}
    DT.filter_params(keys, 1)
    var attributes_for_filtering = {"attributes": keys}
    return attributes_for_filtering;
   }
  }
  var filter_params = function(keys, level) {
    var selector = $('.custom_level_' + level + ' .clicked')
    if (typeof(selector) != 'undefined' && selector.size() > 0) {
      keys[selector.parent().attr('data-scope')] =  selector.attr('data-key')
      filter_params(keys, level+1)
    }
  }
  return {
  	filters: filters,
    filter_params: filter_params,
  }
})()