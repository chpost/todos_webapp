# frozen_string_literal: true

require 'sinatra'
require 'sinatra/content_for'
require 'sinatra/reloader' if development?
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# GET  /lists       -> view all lists
# GET  /lists/new   -> new list form
# POST /lists       -> create new list
# GET  /lists/1     -> view a single list

# View list of lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'List name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique.'
  end
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

def next_list_id
  session[:lists].map { |list| list[:id] }.max + 1
end

# View an existing todo list
get '/lists/:id' do |id|
  @list_id = id.to_i
  @list = session[:lists][@list_id]
  erb :list, layout: :layout
end

# Edit an existing todo list
get '/lists/:id/edit' do |id|
  @list = session[:lists][id.to_i]
  erb :edit_list, layout: :layout
end

# Update an existing todo list
post '/lists/:id' do |id|
  @list = session[:lists][id.to_i]
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{id}"
  end
end

# Delete an existing todo list
post '/lists/:id/destroy' do |id|
  session[:lists].delete_at(id.to_i)
  session[:success] = 'The list has been removed.'
  redirect '/lists'
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_todo(name)
  if !(1..100).cover? name.size
    'Todo must be between 1 and 100 characters.'
  end
end

# Add todo item to current list
post '/lists/:list_id/todos' do |list_id|
  @list_id = list_id.to_i
  @list = session[:lists][@list_id]
  text = params[:todo].strip
  error = error_for_todo(text)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: text, completed: false }
    session[:success] = 'The todo was added.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post '/lists/:list_id/todos/:todo_id/destroy' do |list_id, todo_id|
  @list_id = list_id.to_i
  session[:lists][@list_id][:todos].delete_at(todo_id.to_i)
  session[:success] = 'The todo has been deleted.'
  redirect "/lists/#{list_id}"
end

helpers do
  def sort_lists(lists, &block)
    complete, incomplete = lists.partition { |list| list_complete?(list) }

    incomplete.each { |list| yield list, lists.index(list) }
    complete.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    complete, incomplete = todos.partition { |todo| todo[:completed] }

    incomplete.each { |todo| yield todo, todos.index(todo) }
    complete.each { |todo| yield todo, todos.index(todo) }
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def list_complete?(list)
    todos_remaining_count(list) == 0 && todos_count(list) > 0
  end

  def todo_class(todo)
    "complete" if todo[:completed]
  end

  def todos_remaining_count(list)
    list[:todos].reject { |todo| todo[:completed] }.size
  end

  def todos_count(list)
    list[:todos].size
  end
end

# Update the status of a todo
post '/lists/:list_id/todos/:todo_id' do |list_id, todo_id|
  todo = session[:lists][list_id.to_i][:todos][todo_id.to_i]
  is_completed = params[:completed] == 'true'
  todo[:completed] = is_completed

  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{list_id}"
end

post '/lists/:id/complete_all' do |id|
  session[:lists][id.to_i][:todos].each { |todo| todo[:completed] = true }

  session[:success] = 'All todos have been completed.'
  redirect "/lists/#{id}"
end
