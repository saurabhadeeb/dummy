class CompaniesController < ApplicationController
  def show
    Rails.logger.debug("Inside CompaniesController -> show")
    @company = Company.new
  end
  
  
 def create
   Rails.logger.debug("Inside CompaniesController -> create")
   Rails.logger.debug params.inspect
 end
 
 def doclib
   Rails.logger.debug "Inside CompaniesController-doclib action."
   Rails.logger.debug params.inspect
   domain = "xlri"
   resource_full_path = "public/" + domain
   if !params[:resource].blank?
     resource_full_path += "/"+ params[:resource]
   end
   if !params[:resource].blank?
     @doclib_breadcrumbs = Array.new
     prev_path = String.new
     tree = params[:resource].split('/')
     tree.each do |node|
       node_hash = Hash.new
       node_hash[:name] = node.titleize
       if !prev_path.blank?
         prev_path = prev_path + '/' + node
       else
         prev_path = node
       end
       node_hash[:query] = prev_path
       @doclib_breadcrumbs << node_hash
     end
   end
   
   Rails.logger.debug "requested resource path #{resource_full_path.inspect}"
   if Dir.exists?(resource_full_path)
     listing = Dir.glob(resource_full_path+"/*").sort
     @directories = Array.new
     @files = Array.new
     listing.each do |fname|
       fn_hash = Hash.new
       # Remove the public/<domain> directories from the path
       relative_path = fname.sub(fname.split('/')[0..1].join('/')+'/',"")
       Rails.logger.debug "Relative path is #{relative_path.inspect}"
       # Replace - and _ with a space
       basename = Pathname.new(fname).basename.to_s.gsub('-',' ')
       well_formed_name = basename.gsub('_',' ')
       if Dir.exists?(fname)
         dir_hash = Hash.new
         # Capitalize 1st letter of each word. Titleize does this but makes others lowercase
         well_formed_name = well_formed_name.gsub(/\b\w/){ $&.upcase }
         dir_hash[:relative_path] = relative_path
         dir_hash[:basename] = well_formed_name
         dir_hash[:icon] = "/img/folder-icon.png"
         @directories << dir_hash
       else
         file_hash = Hash.new
         split_name=well_formed_name.split('.')
         extn = split_name.last
         size=split_name.size
         # well_formed_name = split_name[0..size-2].join(' ').titleize + '.'+split_name[size-1]
         well_formed_name = split_name[0..size-2].join(' ')
         # Capitalize 1st letter of each word. Titleize does this but makes others lowercase
         well_formed_name = well_formed_name.gsub(/\b\w/){ $&.upcase }
         file_hash[:relative_path] = relative_path
         file_hash[:basename] = well_formed_name
         case extn.downcase
         when "ppt", "pptx"
           file_hash[:icon] = "/img/ppt_icon.png"
         when "doc", "docx"
           file_hash[:icon] = "/img/doc-icon.png"
         when "xls", "xlsx"
           file_hash[:icon] = "/img/xls-icon.png"
         when "pdf"
           file_hash[:icon] = "/img/pdf-icon.png"
         when "jpg", "jpeg", "png", "gif"
           file_hash[:icon] = "/img/img-icon.png"
         else
           file_hash[:icon] = "/img/other-file_type.png"
         end
         @files << file_hash
       end
     end
   else if File.exists?(resource_full_path)
       # not a directory, display the file
       # get the file extn and assume that it will be the type
       extn = params[:resource].split('.').last
       case extn
       when "doc", "docx", "ppt", "pptx", "xls", "xlsx"
         @doctype = "ms_office"
         @rsc_loc = request.scheme + "://" + request.host
         @rsc_loc += ":" + request.port.to_s if !request.port.blank?
         @rsc_loc += '/' + resource_full_path.split('/').drop(1).join('/')
       else
         Rails.logger.debug "Redirecting to view/download resource directly"
         redirect_to_resource = '/' + resource_full_path.split('/').drop(1).join('/')
         redirect_to redirect_to_resource
       end
     else
       redirect_to companies_doclib_path, :flash => { :error => "Oops! Looks like you tried to access an invalid resource." }
     end
   end
 end
 
 def data
   require 'open-uri'
   require 'open_uri_redirections'
   
   url=params[:url].squish
   
   unless url[/\Ahttp:\/\//] || url[/\Ahttps:\/\//]
     Rails.logger.debug "Adding the http:// since user did not provide it."
     url = "http://#{url}"
   end
  
   if !(url =~ URI::DEFAULT_PARSER.regexp[:ABS_URI])
     Rails.logger.debug "Invalid URL passed"
     #Invalid URL handling
     return
   end
   
   begin
     resp = open(url, :allow_redirections => :all)
     if resp.content_type.in?(['image/png','image/jpeg','image/gif','image/bmp','image/svg+xml'])
       url_for="image"
     elsif resp.content_type.in?(['application/pdf','application/x-pdf','application/msword',
           'application/vnd.ms-excel','application/vnd.ms-powerpoint'])
       url_for="document"
     elsif resp.content_type.in?(['text/html'])
       url_for="website"
       page=Nokogiri::HTML(resp.read)
     else
       url_for="unknown"
     end

     @final_url = resp.base_uri.to_s
   rescue => ex
     Rails.logger.debug "Error in fetching URL provided."
     @final_url = url
     errorInURL=true
   end

   if !errorInURL and url_for=="website"
      if !page.css("base").blank? and !page.css("base").first.attributes["href"].blank?
        @base_url=page.css("base").first.attributes["href"].value.to_s
      else
        @base_url=@final_url
      end
      Rails.logger.debug("Base URL: #{@base_url.inspect}")

      @final_img_srcs=Array.new
      @slide_images = Array.new
      @slideshow = false
      @og_image_found = false

      host = URI.parse(@final_url).host

      if host.include?("youtube.com") or host.include?("vimeo.com")
        @video = VideoInfo.new(@final_url)
        get_description(page, resp)
        download_name = ViddlRb.get_names(@final_url).first
        ext = File.extname(download_name)
        @generated_filename=Time.now.strftime("%Y%m%d%H%M%S")+(rand * 1000000).round.to_s + ext
        # download_and_store_video(download_name)
      elsif host.include?("slideshare.net")
        @slideshow = true
        get_title(page)
        get_description(page,resp)
        get_slideshare_embed_url(page)
        #download_slides(page)
      else
        # Get the title from either og:title or from title tag 
        get_title(page)

        # Get the image if specified by og:image property */
        get_og_image(page)

        #Get the snippet 
        get_description(page, resp)

        if @resolved_text.blank?
          get_content_from_response(resp)
        end
        num_words = @resolved_text.split.size
        @reading_minutes = num_words/100
      end
   elsif !errorInURL and url_for=="image"
     # Fetch the image and store it such that it becomes the KB's og:image that shows in the preview
     # Here, the description and reading_minutes and offline content should be made blank, if they are not already
      @image_url=true
      @reading_minutes=0
   elsif !errorInURL and url_for=="document"
     # og:image should be the default image in this case.
     # Also, no description can be provided so it should be blank with reading mins as 0
     @doc_url=true
     @reading_minutes=0
   else
     @reading_minutes = 0
     @resolved_text = "No preview available!"
   end
 end
 
 def download_and_store_video(downloaded_filename)
   Rails.logger.debug "Downloading and storing the video file"
   Rails.logger.debug "Downloaded filename will be #{downloaded_filename}"
   Rails.logger.debug "Stored filename will be #{@generated_filename}"
   system("viddl-rb", "#{@final_url}", "--save-dir", "public/videos")
   FileUtils.mv "public/videos/#{downloaded_filename}", "public/videos/#{@generated_filename}"
 end
 
 def get_title(page)
   if !page.css("meta[property='og:title']").blank?
     Rails.logger.debug("In CompaniesController-get_title - Found og:title")
     @title=page.css("meta[property='og:title']").first.attributes["content"].value.to_s
   end
   if @title.blank? and !page.css("title").blank?
     Rails.logger.debug("Getting title tag content")
     @title=page.css("title").children.to_s
   end
   @title=HTMLEntities.new.decode(@title).squish
   Rails.logger.debug @title.inspect
 end

 # ONLY FOR SLIDESHARE
 def get_slideshare_embed_url(page)
   if !page.css("meta[name='twitter:player']").blank?
     Rails.logger.debug("In CompaniesController-get_slideshare_embed_url - Found meta name=twitter:player")
     @embed_url=page.css("meta[name='twitter:player']").first.attributes["value"].value.to_s
     Rails.logger.debug("Slideshare embed url is #{@embed_url}")
   end
 end

 def get_description(page, resp)
  # Get the snippet from either in order of priority
  # 1. og:description
  # 2. meta desciption
  # 3. First 150 characters of the content */
   if !page.css("meta[property='og:description']").blank?
     Rails.logger.debug("In CompaniesController-get_description - Found og:description")
     @description=page.css("meta[property='og:description']").first.attributes["content"].value.to_s
   end
   if @description.blank? and !page.css("meta[name='description']").blank?
     Rails.logger.debug("In CompaniesController-get_description - Found meta name=description")
     @description=page.css("meta[name='description']").first.attributes["content"].value.to_s
   end
   if @description.blank? and !page.css("meta[name='Description']").blank?
     Rails.logger.debug("In CompaniesController-get_description - Found meta name=Description")
     @description=page.css("meta[name='Description']").first.attributes["content"].value.to_s
   end
   if @description.blank?
     Rails.logger.debug("In CompaniesController-get_description - description is blank. Get from content")
     get_desc_from_content(resp)
   end
   # Resolve the HTML entity references inside the text
   @description=HTMLEntities.new.decode(@description).squish
   Rails.logger.debug(@description.inspect)
 end
 
 def get_content_from_response(resp)
   Rails.logger.debug("In CompaniesController-get_content_from_response")
   file=File.open(resp,"r")
   source = file.read
   File.delete(file)
   document = Readability::Document.new(source, :tags => %w[div p img a ul ol li code h1 h2 h3 h4 h5],
     :attributes => %w[src href style align alt start], :remove_empty_nodes => false,
     :min_image_width=>10, :min_image_height=>10)
   
   # Get and replace images
   p = Nokogiri::HTML::DocumentFragment.parse(document.content)
   Rails.logger.debug "Number of images is #{p.search('img').count}"
   p.search('img').each do |i|
     begin
       img_hash=Hash.new
       src = URI.encode(i['src'])
       Rails.logger.debug "src = #{src}"
       basename = File.basename(URI.parse(src).path)
       Rails.logger.debug "basename = #{basename}"
       Rails.logger.debug "Fetching image with src #{URI.join(@base_url, src)}"
       open(URI.join(@base_url,src)) { |f|
         FileUtils::mkdir_p "public/img" unless Dir.exists?("public/img")
         File.open("public/img/#{basename}","wb") do |file|
            file.puts f.read
        end
        }
        current_scheme=request.scheme
        current_host=request.host
        current_port=request.port
        i['src']="#{current_scheme}://#{current_host}:#{current_port}/img/#{basename}"
        if !@og_image_found
          size=FastImage.size("public/img/#{basename}")
          if !size.blank?
            Rails.logger.debug {src+" Size:["+size[0].to_s+","+size[1].to_s+"]"}
            if (size[0]>=120 or size[1]>=120)
              img_hash[:url]="#{current_scheme}://#{current_host}:#{current_port}/img/#{basename}"
              img_hash[:size]=size.inject(:*)
              Rails.logger.debug img_hash.inspect
              @final_img_srcs<<img_hash
              break if @final_img_srcs.count == 5
            end
          end
        end
     rescue Exception => ex
       Rails.logger.debug "Get and replace images. Error in handling image no. #{i.to_s}. Continuing to next iteration."
       next
     end
   end
   
   # Replace all anchor URLs with absolute URLs
   p.search('a').each do |a|
     begin
       href = URI.encode(a['href'])
       Rails.logger.debug "href = #{href}"
       a['href']=URI.join(@base_url,href).to_s
       Rails.logger.debug "New href = #{a['href']}"
     rescue Exception => ex
       Rails.logger.debug "Error in resolving URL in href. #{a.to_s}. Continuing to next iteration."
       next
     end
   end
   
   @page_content = p.to_html
   @final_img_srcs.sort_by { |hsh| hsh[:size] }
   Rails.logger.debug @final_img_srcs.inspect
   clean_text = ActionView::Base.full_sanitizer.sanitize(@page_content)
   @resolved_text=HTMLEntities.new.decode(clean_text).squish
 end
 
 def get_desc_from_content(resp)
   Rails.logger.debug("In CompaniesController-get_desc_from_content")
   get_content_from_response(resp)
   @description=truncate(@resolved_text,150)
 end
 
 def get_og_image(page)
   image = page.css("meta[property='og:image']").first.attributes["content"].value.to_s unless page.css("meta[property='og:image']").blank?
   if !image.blank?
     Rails.logger.debug("In CompaniesController-get_og_image - Found og:image")
     begin
       basename = File.basename(URI.parse(image).path)
       open(URI.join(@base_url,image)) { |f|
        FileUtils::mkdir_p "public/img" unless Dir.exists?("public/img")
        File.open("public/img/#{basename}","wb") do |file|
          file.puts f.read
       end
       }
     rescue => ex
       Rails.logger.debug "Found an exception in openURI. Returning"
       @og_image_found=false
       return
     end
     Rails.logger.debug "Getting size of specified og image"
     size=FastImage.size("public/img/#{basename}")
     Rails.logger.debug "Size is blank" if size.blank?
     if !size.blank?
       Rails.logger.debug {image+" Size:["+size[0].to_s+","+size[1].to_s+"]"}
       img_hash=Hash.new
       current_scheme=request.scheme
       current_host=request.host
       current_port=request.port
       img_hash[:url]="#{current_scheme}://#{current_host}:#{current_port}/img/#{basename}"
       img_hash[:size]=size.inject(:*)
       @final_img_srcs<<img_hash
       @og_image_found=true
     else
       File.delete("public/img/#{basename}")
     end
   end
   Rails.logger.debug @final_img_srcs.inspect
 end
 
 def truncate(s, max=100, elided = ' ...')
   s.match( /(.{1,#{max}})(?:\s|\z)/ )[1].tap do |res|
     res << elided unless res.length == s.length
   end    
 end
 
 def get_yt_video_id(url)
   yt_uri = URI.parse(url)
   if yt_uri.path =~ /watch/
     @video_id = CGI::parse(yt_uri.query)["v"].first
   else
     @video_id = yt_uri.path
   end
   Rails.logger.debug "Video id found: #{@video_id}"
 end

 def download_slides(page)
   Rails.logger.debug "Inside download_slides method"
   if !page.css("div[data-index]").blank?
     number_of_slides = page.css("div[data-index]").count
     Rails.logger.debug "No. of slides is #{number_of_slides}"
     dir_name="slides/"+File.dirname(@final_url).split("/").last+"/"+
       File.basename(@final_url).split("?").first
     dir_name_with_public="public/"+dir_name
     FileUtils::mkdir_p dir_name_with_public unless Dir.exists?(dir_name_with_public)
     page.css("img.slide_image").each_with_index do |slide, index|
       src=slide['data-normal']
       src=src.split("?")[0]
       Rails.logger.debug "src #{index+1} is #{src}"
       basename = File.basename(URI.parse(src).path)
       open(URI.join(@base_url,src)) { |f|
         File.open("#{dir_name_with_public}/#{basename}","wb") do |file|
           file.puts f.read
         end
       }
       current_scheme=request.scheme
       current_host=request.host
       current_port=request.port
       img_url="#{current_scheme}://#{current_host}:#{current_port}/#{dir_name}/#{basename}"
       @slide_images<<img_url
     end
   else
     Rails.logger.debug "No div with slidenumber found"
   end
 end
end
