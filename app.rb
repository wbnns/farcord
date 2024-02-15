require 'sinatra'
require 'dotenv'
require 'httparty'
require 'json'
require 'sqlite3'

Dotenv.load

BASE_URL = "https://warpcast.com"

# Initialize SQLite database and create table if not exists
def init_db
  db = SQLite3::Database.new "casts.db"
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS processed_casts (
      id INTEGER PRIMARY KEY,
      cast_hash VARCHAR(255) UNIQUE NOT NULL,
      username VARCHAR(255) NOT NULL
    );
  SQL
  db
end

# Fetches the most recent casts from Neynar and processes them
def fetch_and_process_casts
  url = "https://api.neynar.com/v2/farcaster/feed/channels?channel_ids=base&with_recasts=true&with_replies=false&limit=100"
  response = HTTParty.get(url, headers: { "accept" => "application/json", "api_key" => ENV['NEYNAR_API_KEY'] })
  return unless response.success?

  casts = JSON.parse(response.body)["casts"]
  casts.each do |cast|
    cast_hash = cast["hash"]
    username = cast["author"]["username"]
    next if cast_exists?(cast_hash)

    process_cast(cast_hash, username)
  end
end

# Check if a cast already exists in the database
def cast_exists?(cast_hash)
  DB.execute("SELECT 1 FROM processed_casts WHERE cast_hash = ?", cast_hash).any?
end

# Process a new cast and store it in the database
def process_cast(cast_hash, username)
  DB.execute("INSERT INTO processed_casts (cast_hash, username) VALUES (?, ?)", cast_hash, username)
end

# Fetch all processed casts from the database
def fetch_all_links
  rows = DB.execute("SELECT username, cast_hash FROM processed_casts")
  rows.map { |username, hash| "#{BASE_URL}/#{username}/#{hash}" }
end

# Initialize database
DB = init_db

get '/fetch_and_process' do
  fetch_and_process_casts
  "Casts fetched and processed successfully!"
end

get '/links' do
  @links = fetch_all_links
  erb :links
end

