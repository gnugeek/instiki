require 'application'
require 'fileutils'
require 'redcloth_for_tex'

class WikiController < ApplicationController

  before_filter :pre_process

  EXPORT_DIRECTORY = File.dirname(__FILE__) + "/../../storage/" unless const_defined?("EXPORT_DIRECTORY")

  def index
    if @web_name
      redirect_show 'HomePage'
    elsif not wiki.setup?
      redirect_to :action => 'new_system'
    elsif wiki.webs.length == 1
      redirect_show 'HomePage', wiki.webs.values.first.address
    else
      redirect_to :action => 'web_list'
    end
  end

  # Administrating the Instiki setup --------------------------------------------

  def create_system
    wiki.setup(@params['password'], @params['web_name'], @params['web_address']) unless wiki.setup?
    redirect_to :action => 'index'
  end

  def create_web
    if wiki.authenticate(@params['system_password'])
      wiki.create_web(@params['name'], @params['address'])
      redirect_show('HomePage', @params['address'])
    else 
      redirect_to :action => 'index'
    end
  end

  def new_system
    redirect_to(:action => 'index') if wiki.setup?
    # otherwise, to template
  end
  
  def new_web
    redirect_to :action => 'index' if wiki.system['password'].nil?
    # otherwise, to template
  end


  # Outside a single web --------------------------------------------------------

  def authenticate
    if password_check(@params['password'])
      redirect_show('HomePage')
    else 
      redirect_to :action => 'login'
    end
  end

  def login
    # go straight to template
  end
  
  def web_list
    @webs = wiki.webs.values.sort_by { |web| web.name }
  end


  # Within a single web ---------------------------------------------------------

  def authors
    @authors = @web.select.authors
  end
  
  def export_html
    export_pages_as_zip('html') { |page| @page = page; render_to_string 'wiki/print' }
  end

  def export_markup
    export_pages_as_zip(@web.markup) { |page| page.content }
  end

  def export_pdf
    file_name = "#{web.address}-tex-#{web.revised_on.strftime("%Y-%m-%d-%H-%M")}"
    file_path = EXPORT_DIRECTORY + file_name

    export_web_to_tex(file_path + ".tex") unless FileTest.exists?(file_path + ".tex")
    convert_tex_to_pdf(file_path + ".tex")
    send_export(file_name + ".pdf", file_path + ".pdf")
  end

  def export_tex
    file_name = "#{web.address}-tex-#{web.revised_on.strftime("%Y-%m-%d-%H-%M")}.tex"
    file_path = EXPORT_DIRECTORY + file_name

    export_web_to_tex(file_path) unless FileTest.exists?(file_path)
    send_export(file_name, file_path)
  end

  def feeds
    # to template
  end

  def list
    parse_category
    @pages_by_name = @pages_in_category.by_name
    @page_names_that_are_wanted = @pages_in_category.wanted_pages
    @pages_that_are_orphaned = @pages_in_category.orphaned_pages
  end
  
  def recently_revised
    parse_category
    @pages_by_revision = @pages_in_category.by_revision
  end

  def remove_orphaned_pages
    if wiki.authenticate(@params['system_password'])
      wiki.remove_orphaned_pages(@web_name)
      redirect_to :action => 'list'
    else
      redirect_show 'HomePage'
    end
  end

  def rss_with_content
    render_rss
  end

  def rss_with_headlines
    render_rss(hide_description = true)
  end

  def search
    @query = @params['query']
    @results = @web.select { |page| page.content =~ /#{@query}/i }.sort
    redirect_show(@results.first.name) if @results.length == 1
  end

  def update_web
    if wiki.authenticate(@params['system_password'])
      wiki.update_web(
        @web.address, @params['address'], @params['name'], 
        @params['markup'].intern, 
        @params['color'], @params['additional_style'], 
        @params['safe_mode'] ? true : false, 
        @params['password'].empty? ? nil : @params['password'],
        @params['published'] ? true : false, 
        @params['brackets_only'] ? true : false,
        @params['count_pages'] ? true : false
      )
      redirect_show('HomePage', @params['address'])
    else
      redirect_show('HomePage') 
    end
  end
  

  # Within a single page --------------------------------------------------------
  
  def cancel_edit
    @page.unlock
    redirect_show
  end
  
  def edit
    if @page.nil?
      redirect_to :action => 'index'
    elsif @page.locked?(Time.now) and not @params['break_lock']
      redirect_to :web => @web_name, :action => 'locked', :id => @page_name
    else
      @page.lock(Time.now, @author)
    end
  end
  
  def locked
    # to template
  end
  
  def new
    # go straight to template, all necessary variables are already set in the filter
  end

  def pdf
    page = wiki.read_page(@web_name, @page_name)
    safe_page_name = @page.name.gsub(/\W/, '')
    file_name = "#{safe_page_name}-#{@web.address}-#{@page.created_at.strftime("%Y-%m-%d-%H-%M")}"
    file_path = EXPORT_DIRECTORY + file_name

    export_page_to_tex(file_path + '.tex') unless FileTest.exists?(file_path + '.tex')
    convert_tex_to_pdf(file_path + '.tex')
    send_file(file_name + '.pdf')
  end

  def print
    # to template
  end

  def published
    if @web.published
      @page = wiki.read_page(@web_name, @page_name || 'HomePage') 
    else 
      redirect_show('HomePage') 
    end
  end
  
  def revision
    get_page_and_revision
  end

  def rollback
    get_page_and_revision
  end

  def save
    redirect_to :action => 'index' if @page_name.nil?

    if @web.pages[@page_name]
      page = wiki.revise_page(
          @web_name, @page_name, @params['content'], Time.now, 
          Author.new(@params['author'], remote_ip)
      )
      page.unlock
    else
      page = wiki.write_page(
          @web_name, @page_name, @params['content'], Time.now, 
          Author.new(@params['author'], remote_ip)
      )
    end
    cookies['author'] = @params['author']
    redirect_show(@page_name)
  end

  def show
    if @page
      begin
        render_action 'page'
      # TODO this rescue should differentiate between errors due to rendering and errors in 
      # the application itself (for application errors, it's better not to rescue the error at all)
      rescue => e
        logger.error e
        if in_a_web?
          redirect_to :web => @web_name, :action => 'edit',
              :action_suffix => "#{CGI.escape(@page_name)}?msg=#{CGI.escape(e.message)}"
        else
          raise e
        end
      end
    else
      redirect_to :web => @web_name, :action => 'new', :id => CGI.escape(@page_name)
    end
  end

  def tex
    @tex_content = RedClothForTex.new(@page.content).to_tex
  end


  private
    
  def authorized?
    @web.nil? ||
    @web.password.nil? || 
    cookies['web_address'] == @web.password || 
    password_check(@params['password'])
  end

  def check_authorization(action_name)
    if in_a_web? and 
        not authorized? and 
        not %w( login authenticate published ).include?(action_name)
      redirect_to :action => 'login'
      return false
    end
  end

  def convert_tex_to_pdf(tex_path)
    `cd #{File.dirname(tex_path)}; pdflatex --interaction=scrollmode '#{File.basename(tex_path)}'`
  end

  def export_page_to_tex(file_path)
    tex
    File.open(file_path, 'w') { |f| f.write(template_engine("tex").result(binding)) }
  end
  
  def export_pages_as_zip(file_type, &block)

    file_prefix = "#{@web.address}-#{file_type}-"
    timestamp = @web.revised_on.strftime('%Y-%m-%d-%H-%M-%S')
    file_path = EXPORT_DIRECTORY + file_prefix + timestamp + '.zip'
    tmp_path = "#{file_path}.tmp"

    Zip::ZipOutputStream.open(tmp_path) do |zip_out|
      @web.select.by_name.each do |page|
        zip_out.put_next_entry("#{page.name}.#{file_type}")
        zip_out.puts(block.call(page))
      end
      # add an index file, if exporting to HTML
      if file_type.to_s.downcase == 'html'
        zip_out.put_next_entry 'index.html'
        zip_out.puts <<-EOL
          <html>
            <head>
              <META HTTP-EQUIV="Refresh" CONTENT="0;URL=HomePage.#{file_type}">
            </head>
          </html>
        EOL
      end
    end
    FileUtils.rm_rf(Dir[EXPORT_DIRECTORY + file_prefix + '*.zip'])
    FileUtils.mv(tmp_path, file_path)
    send_file(file_path, :type => 'application/zip')
  end

  def export_web_to_tex(file_path)
    @tex_content = table_of_contents(web.pages['HomePage'].content.dup, render_tex_web)
    File.open(file_path, 'w') { |f| f.write(template_engine('tex_web').result(binding)) }
  end

  def get_page_and_revision
    @revision = @page.revisions[@params['rev'].to_i]
  end

  def in_a_web?
    not @web_name.nil?
  end

  def parse_category
    @categories = @web.categories
    @category = @params['category']
    if @categories.include?(@category)
      @pages_in_category = @web.select { |page| page.in_category?(@category) }
      @set_name = "category '#{@category}'"
    else 
      @pages_in_category = PageSet.new(@web).by_name
      @set_name = 'the web'
    end
    @category_links = @categories.map { |c| 
      if @category == c
        %{<span class="selected">#{c}</span>} 
      else
        %{<a href="?category=#{c}">#{c}</a>}
      end
    }
  end

  def password_check(password)
    if password == @web.password
      cookies['web_address'] = password
      true
    else
      false
    end
  end

  def pre_process
    @action_name = @params['action'] || 'index'
    @web_name = @params['web']
    @wiki = wiki
    @web = @wiki.webs[@web_name] unless @web_name.nil?
    @page_name = @params['id']
    @page = @wiki.read_page(@web_name, @page_name) unless @page_name.nil?
    @author = cookies['author'] || 'AnonymousCoward'
    check_authorization(@action_name)
  end

  def redirect_show(page_name = @page_name, web = @web_name)
    redirect_to :web => web, :action => 'show', :id => CGI.escape(page_name)
  end

  def remote_ip
    ip = @request.remote_ip
    logger.info(ip)
    ip
  end

  def render_rss(hide_description = false)
    @pages_by_revision = @web.select.by_revision.first(15)
    @hide_description = hide_description
    @response.headers['Content-Type'] = 'text/xml'
    render 'wiki/rss_feed'
  end

  def render_tex_web
    @web.select.by_name.inject({}) do |tex_web, page|
      tex_web[page.name] = RedClothForTex.new(page.content).to_tex
      tex_web
    end
  end

  def render_to_string(template_name)
    add_variables_to_assigns
    render template_name
    @template.render_file(template_name)
  end
  
  # Returns an array with each of the parts in the request as an element. So /something/cool/dude
  # returns ["something", "cool", "dude"]
  def request_path
    request_path_parts = @request.path.to_s.split(/\//)
    request_path_parts.length > 1 ? request_path_parts[1..-1] : []
  end

  def template_engine(template_name)
    ERB.new(IO.readlines(RAILS_ROOT + '/app/views/wiki/' + template_name + '.rhtml').join)
  end
  
  def truncate(text, length = 30, truncate_string = '...')
    if text.length > length then text[0..(length - 3)] + truncate_string else text end
  end
  
end
