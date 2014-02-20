class SayController < ApplicationController
  def hello
    @time = Time.now.strftime("%r %D")
  end

  def goodbye
    @files = Dir.glob('*')
  end
end
