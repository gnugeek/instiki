require 'application'

class AdminController < ApplicationController

  layout 'default'

  def create_system
    if @wiki.setup?
      flash[:error] = <<-EOL
          Wiki has already been created in '#{@wiki.storage_path}'. Shut down Instiki and delete 
          this directory if you want to recreate it from scratch.<br/><br/>
          (WARNING: this will destroy content of your current wiki).
      EOL
      redirect_show('HomePage', @wiki.webs.keys.first)
    elsif @params['web_name']
      # form submitted -> create a wiki
      @wiki.setup(@params['password'], @params['web_name'], @params['web_address']) 
      flash[:info] = <<-EOL
          Your new wiki '#{@params['web_name']}' is created!<br/>
          Please edit its home page and press Submit when finished.
      EOL
      redirect_to  :web => @params['web_address'], :controller => 'wiki', :action => 'new', 
          :id => 'HomePage'
    else
      # no form submitted -> go to template
    end
  end

  def create_web
    if @params['address']
      # form submitted
      if @wiki.authenticate(@params['system_password'])
        @wiki.create_web(@params['name'], @params['address'])
        redirect_show('HomePage', @params['address'])
      else 
        redirect_to :controller => 'wiki', :action => 'index'
      end
    else
      # no form submitted -> render template
      if @wiki.system[:password].nil?
        redirect_to :controller => 'wiki', :action => 'index'
      end
    end
  end

  def edit_web
    system_password = @params['system_password']
    if system_password
      # form submitted
      if wiki.authenticate(system_password)
        begin
          wiki.edit_web(
            @web.address, @params['address'], @params['name'], 
            @params['markup'].intern, 
            @params['color'], @params['additional_style'], 
            @params['safe_mode'] ? true : false, 
            @params['password'].empty? ? nil : @params['password'],
            @params['published'] ? true : false, 
            @params['brackets_only'] ? true : false,
            @params['count_pages'] ? true : false,
            @params['allow_uploads'] ? true : false,
            @params['max_upload_size']
          )
          flash[:info] = "Web '#{@params['address']}' was successfully updated"
          redirect_show('HomePage', @params['address'])
        rescue Instiki::ValidationError => e
          flash[:error] = e.message
          # and re-render the same template again
        end
      else
        flash[:error] = password_error(system_password)
        # and re-render the same template again
      end
    else
      # no form submitted - go to template
    end
  end

  def remove_orphaned_pages
    if wiki.authenticate(@params['system_password_orphaned'])
      wiki.remove_orphaned_pages(@web_name)
      flash[:info] = 'Orphaned pages removed'
      redirect_to :controller => 'wiki', :web => @web_name, :action => 'list'
    else
      flash[:error] = password_error(@params['system_password'])
      return_to_last_remembered
    end
  end

end
