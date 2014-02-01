require 'bundler'
require 'json'
require 'securerandom'
require 'time'
Bundler.require :default
require 'sinatra/reloader' if development?

configure do
  use Rack::Session::Cookie, secret: ENV['COOKIE_SECRET']

  DB = begin
    Sequel.connect(ENV['DATABASE_URL'])
  rescue
    Sequel.connect('sqlite://test.db')
  end
  
  require './models'

  MKD = Redcarpet::Markdown.new Redcarpet::Render::HTML,
    autolink: true,
    disable_indented_code_blocks: true,
    fenced_code_blocks: true,
    highlight: true,
    quote: true,
    strikethrough: true,
    superscript: true,
    tables: true
end

helpers do
  def a(href, text, o = {})
    o[:rel] = o[:rel] ? "rel=\"#{[o[:rel]].join(' ')}\" " : ""
    o[:title] = o[:title] ? "title=\"#{[o[:title]].join(' ')}\" " : ""
    "<a #{o[:rel]}#{o[:title]}href=\"#{href}\">#{text}</a>"
  end

  def mkd raw
    MKD.render raw
  end

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

  def id_user
    like_ip = User.where(Sequel.like(:ips_used, "%:#{request.ip}:%"))
    session[:user] = nil
    like_sess = User.where(Sequel.like(:session_ids, "%:#{session[:session_id]}:%"))
    like_date = User.where{date_last_seen > DateTime.now.prev_day}

    user = if like_sess.first
      like_sess.first
    else
      like_heur = (like_ip.all || []) & (like_date.all || [])
      if like_heur.size > 1
        like_heur.sort_by{|o| o.date_last_seen}.first
      elsif like_heur.size == 1
        like_heur.first
      else
        if like_ip.all.size > 1
          like_ip.all.sort_by{|o| o.date_last_seen}.first
        elsif like_ip.all.size == 1
          like_ip.first
        else
          User.new
        end
      end
    end

    user.save
    session[:user] = user.id

    user.date_last_seen = DateTime.now

    user.ips_used ||= ':'
    ips = user.ips_used.split(':').drop(1)
    user.ips_used += "#{request.ip}:" unless ips.include? request.ip

    user.session_ids ||= ':'
    ids = user.session_ids.split(':').drop(1)
    user.session_ids += "#{session[:session_id]}:" unless ids.include? session[:session_id]

    user.save
  end

  alias_method :current_user, :id_user
end

before '/api/*' do
  content_type 'application/json'
end

get '/' do
  haml :index
end

get '/test/:id' do
  @test = Test[params[:id]]
  if @test
    haml :test
  else
    haml :_404
  end
end

get '/resource/:file' do
  name, ext = params[:file].split '.'
  eng, type = {
    'js'  => [:coffee,  'application/javascript'],
    'css' => [:scss,    'text/css']
  }[ext]

  content_type type
  send eng, ['resource', name].join('/').to_sym
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

  data = test.to_hash.reject{|k| [:key, :user_id].include? k}
  data['cases'] = test.cases.map{|c| c.to_hash.reject{|k| [:test_id, :user_id].include? k}}.shuffle
  data.to_json
end

post '/api/test' do
  read_json_params params
  # Create test
  
  test = Test.new
  test.key = SecureRandom.hex(512)
  test.title = params['title'] if params['title']
  test.date_created = DateTime.now
  test.user = id_user
  
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
  cas.user = id_user

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

get '/api/vote' do
  read_json_params params
  # Get current vote

  halt 400, {error: 'No id given'}.to_json unless params['id']

  test = Test[params['id']]

  halt 404, {error: 'Test not found'}.to_json unless test

  begin
    user = id_user
    cho = user.choices.select{|c| c.test_id == test.id}.first
    vote = if cho
      cho.case_id
    else
      nil
    end
  rescue Exception => e
    [500, {error: e.to_s}.to_json]
  else
    [200, {case: vote}.to_json]
  end
end

post '/api/vote' do
  read_json_params params
  # Place a vote

  halt 400, {error: 'No id given'}.to_json unless params['id']
  halt 400, {error: 'No case given'}.to_json unless params['case']

  test = Test[params['id']]

  halt 404, {error: 'Test not found'}.to_json unless test

  cas = Case[params['case']]

  halt 404, {error: 'Case not found'}.to_json unless cas
  halt 404, {error: 'Case not found'}.to_json unless test.cases.include? cas

  user = id_user
  vote = user.choices.select{|c| c.test_id == test.id}.first
  unless vote
    vote = Choice.new
    vote.test = test
    vote.user = user
  end

  vote.case = cas
  vote.date_created = DateTime.now

  begin
    vote.save
  rescue Exception => e
    [500, {error: e.to_s}.to_json]
  else
    [200, {id: vote.id}.to_json]
  end
end

delete '/api/vote' do
  read_json_params params
  # Unvote
  session[:vote] ||= {}

  halt 400, {error: 'No id given'}.to_json unless params['id']

  test = Test[params['id']]

  halt 404, {error: 'Test not found'}.to_json unless test

  user = id_user
  vote = user.choices.select{|c| c.test_id == test.id}.first

  halt 403, {error: 'Not voted yet'}.to_json unless vote

  begin
    vote.destroy
  rescue Exception => e
    [500, {error: e.to_s}.to_json]
  else
    [200, {id: vote.id}.to_json]
  end
end
