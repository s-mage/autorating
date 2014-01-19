require 'sequel'

CONFIG_FILE = File.expand_path '~/.config/mpd_autorating'
DB = Sequel.sqlite CONFIG_FILE

DB.create_table :rating do
  primary_key :id
  Float :skip_rating
  Float :age_rating
  Integer :listen_count
end
