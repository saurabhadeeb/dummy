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
    @list_of_tweets = {}
    search_text='"'+params[:id]+'"'+" -job -jobs filter:links"
    search_query = URI.encode(search_text)
    opts = {:result_type=>"recent", :lang=>"en", :count=>"200"}
    @tweets = Twitter_client.search(search_query, opts)
  end
end