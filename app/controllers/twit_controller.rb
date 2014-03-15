class TwitController < ApplicationController
  Topics_file = "app/assets/topics.txt"
  
  def index
    topic_index=0
    f = File.open(Topics_file, "r")
    @topic_listing = []
    f.each_line {|line|
      next if line.blank?
      if !line.starts_with?(" ")
        topic=line.squish
        @topic_listing[topic_index]=Hash.new
        @topic_listing[topic_index]={:topic => topic, :subtopics => []}
        topic_index += 1
      else
        subtopic=line.squish
        @topic_listing[topic_index-1][:subtopics]<<subtopic
      end  
    }
  end
  
  def search
    Rails.logger.debug "Inside TwitController - search"
    @list_of_tweets = {}
    search_text='"'+params[:id]+'"'+" -job -jobs filter:links"
    search_query = URI.encode(search_text)
    Rails.logger.debug "Search query is #{search_query}"
    opts = {:result_type=>"recent", :lang=>"en", :count=>"200"}
    twit_results = Twitter_client.search(search_query, opts)
    @tweets = Array.new
    expanded_urls = Array.new
    Rails.logger.debug "No. of tweets returned: #{twit_results.count}"
    twit_results.each_with_index do |t, index|
      Rails.logger.debug "=== #{index+1}. #{t.urls.inspect}"
      unless t.urls.blank?
        tweeted_url = t.urls.first.expanded_url.to_s
        if !expanded_urls.include?(tweeted_url)
          expanded_urls << tweeted_url
          tweet_row = Hash.new
          tweet_row[:tweet]=t
          tweet_row[:url]=tweeted_url
          @tweets << tweet_row
        end
      end
    end
  rescue Twitter::Error => e
    @error = e
  end
end