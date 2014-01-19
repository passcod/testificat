require 'bundler'
require 'json'
require 'securerandom'
require 'time'
Bundler.require :default
require 'sinatra/reloader' if development?

configure do
  DB = begin
    Sequel.connect(ENV['DATABASE_URL'])
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

before '/api/*' do
  content_type 'application/json'
end

helpers do
  def read_json_params(parms)
    begin
      request.body.rewind
      j = JSON.parse request.body.read
      parms[:json] = true
      j.each { |k,i|
        parms["_#{k}"] = parms[k] if parms[k]
        parms[k] = i
      }
    rescue Exception => e
      puts e.inspect
    end
  end
end

get '/' do
  haml :index
end

get '/test/:id' do
  haml :test
end

get '/api/test/:id' do
  call! env.merge(
    'PATH_INFO' => '/api/test',
    'QUERY_STRING' => "id=#{params[:id]}"
  )
end

get '/api/test' do
  read_json_params params
  # Retrieve
  
  test = Test[params['id']]
  halt [404, {error: 'Not found'}.to_json] unless test

  data = test.to_hash.reject{|k| k == :key}
  data['cases'] = test.cases.map{|c| c.to_hash.reject{|k| k == :test_id}}.shuffle
  data.to_json
end

post '/api/test' do
  read_json_params params
  # Create test
  
  test = Test.new
  test.key = SecureRandom.hex(512)
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
  read_json_params params
  
  # Add test case
  halt 400, {error: 'No id given'}.to_json unless params['id']
  halt 400, {error: 'No key given'}.to_json unless params['key']
  halt 400, {error: 'No content given'}.to_json unless params['content']

  test = Test[params['id']]

  halt 404, {error: 'Test not found'}.to_json unless test
  halt 403, {error: 'Wrong key'}.to_json unless test.key == params['key']

  cas = Case.new
  cas.test = test
  cas.content = params['content']
  cas.type = params['type'] if params['type']
  cas.title = params['title'] if params['title']
  cas.date_created = DateTime.now

  begin
    cas.save
  rescue Exception => e
    [500, {error: e.to_s}.to_json]
  else
    [200, {id: cas.id}.to_json]
  end
end

delete '/api/test' do
  read_json_params params
  # Remove test case
  
  halt 400, {error: 'No id given'}.to_json unless params['id']
  halt 400, {error: 'No key given'}.to_json unless params['key']
  halt 400, {error: 'No case given'}.to_json unless params['case']

  test = Test[params['id']]

  halt 404, {error: 'Test not found'}.to_json unless test
  halt 403, {error: 'Wrong key'}.to_json unless test.key == params['key']

  cas = Case[params['case']]

  halt 404, {error: 'Case not found'}.to_json unless cas
  halt 404, {error: 'Case not found'}.to_json unless test.cases.include? cas

  begin
    cas.destroy
  rescue Exception => e
    [500, {error: e.to_s}.to_json]
  else
    [200, {id: cas.id}.to_json]
  end
end
