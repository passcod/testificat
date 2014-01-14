require 'bundler'
require 'time'
Bundler.require :default

configure do
end

helpers do
  def a(href, text, o = {})
    o[:rel] = o[:rel] ? "rel=\"#{[o[:rel]].join(' ')}\" " : ""
    o[:title] = o[:title] ? "title=\"#{[o[:title]].join(' ')}\" " : ""
    "<a #{o[:rel]}#{o[:title]}href=\"#{href}\">#{text}</a>"
  end
end

get '/' do
  haml :index
end
