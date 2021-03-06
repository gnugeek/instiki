# Create a route to DEFAULT_WEB, if such is specified; also register a generic route
def connect_to_web(map, generic_path, generic_routing_options)
  if defined? DEFAULT_WEB
    explicit_path = generic_path.gsub(/:web\/?/, '')
    explicit_routing_options = generic_routing_options.merge(:web => DEFAULT_WEB)
    map.connect(explicit_path, explicit_routing_options)
  end
  map.connect(generic_path, generic_routing_options)
end

ActionController::Routing::Routes.draw do |map|
  map.connect 'create_system', :controller => 'admin', :action => 'create_system'
  map.connect 'create_web', :controller => 'admin', :action => 'create_web'
  map.connect 'remove_orphaned_pages', :controller => 'admin', :action => 'remove_orphaned_pages'
  map.connect 'delete_web', :controller => 'admin', :action => 'delete_web'
  map.connect 'web_list', :controller => 'wiki', :action => 'web_list'

  connect_to_web map, ':web/edit_web', :controller => 'admin', :action => 'edit_web'
  connect_to_web map, ':web/files/:id', :controller => 'file', :action => 'file'
  connect_to_web map, ':web/import/:id', :controller => 'file', :action => 'import'
  connect_to_web map, ':web/login', :controller => 'wiki', :action => 'login'
  connect_to_web map, ':web/web_list', :controller => 'wiki', :action => 'web_list'
  connect_to_web map, ':web/show/diff/:id', :controller => 'wiki', :action => 'show', :mode => 'diff'
  connect_to_web map, ':web/revision/diff/:id', :controller => 'wiki', :action => 'revision', :mode => 'diff'
  connect_to_web map, ':web/list', :controller => 'wiki', :action => 'list'
  connect_to_web map, ':web/list/:category', :controller => 'wiki', :action => 'list'
  connect_to_web map, ':web/recently_revised', :controller => 'wiki', :action => 'recently_revised'
  connect_to_web map, ':web/recently_revised/:category', :controller => 'wiki', :action => 'recently_revised'
  connect_to_web map, ':web/:action/:id', :controller => 'wiki'
  connect_to_web map, ':web/:action', :controller => 'wiki'
  connect_to_web map, ':web', :controller => 'wiki', :action => 'index'

  if defined? DEFAULT_WEB
    map.connect '', :controller => 'wiki', :web => DEFAULT_WEB, :action => 'index'
  else
    map.connect '', :controller => 'wiki', :action => 'index'
  end
end
