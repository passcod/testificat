require 'bundler'
require 'json'
require 'securerandom'
require 'time'
Bundler.require :default

configure do
  DB = begin
    Sequel.connect('')
  rescue
    Sequel.connect('sqlite://test.db')
  end
  
  require './models'
end

helpers do
  def a(href, text, o = {})
    o[:rel] = o[:rel] ? "rel=\"#{[o[:rel]].join(' ')}\" " : ""
    o[:title] = o[:title] ? "title=\"#{[o[:title]].join(' ')}\" " : ""
    "<a #{o[:rel]}#{o[:title]}href=\"#{href}\">#{text}</a>"
  end
end

before do
  content_type 'application/json'
  begin
    j = JSON.parse request.body.read
    params[:json] = true
    j.each { |k,i|
      params["_#{k}"] = params[k] if params[k]
      params[k] = i
    }
  rescue Exception
  end
end

get '/' do
  haml :index
end

get '/test/:id' do
  haml :test
end


get '/api/test' do
  # Retrieve
end

post '/api/test' do
  # Create test
  
  test = Test.new
  test.key = SecureRandom.base64(512)
  test.type = params['type'] if params['type']
  test.title = params['title'] if params['title']
  test.date_created = DateTime.now
  
  begin
    test.save
  rescue Exception => e
    [500, {error: e.to_s}.to_json]
  else
    [200, {id: test.id, key: test.key}.to_json]
  end
end

put '/api/test' do
  # Add test case
end

delete '/api/test' do
  # Remove test case
end
