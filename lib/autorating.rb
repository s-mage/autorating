require 'ruby-mpd'
require 'sequel'

class Autorating
  attr_accessor :mpd, :last_playtime, :id
  attr_reader :data, :skip_influence, :age_influence

  CONFIG_FILE = File.expand_path '~/.config/mpd_autorating'
  DB = Sequel.sqlite CONFIG_FILE

  def initialize(host: 'localhost', port: 6600, skip_influence: 0.2,
    age_influence: 1)
    @skip_influence = skip_influence
    @age_influence = age_influence
    @data = DB[:rating]
    @mpd = MPD.new(host, port, callbacks: true)
    mpd.connect
    @id = mpd.current_song.id
    @last_playtime = mpd.stats[:playtime]
  end

  def change_priority
    age_rating = change_age_rate
    skip_rating = change_skip_rate
    rating = (255 * age_rating * skip_rating).to_i
    mpd.song_priority(rating, id)
  end

  def change_age_rate
    listen_count = data[id: id][:listen_count] + 1
    age_rate = 1 / Math.log10(10 + age_influence * listen_count)
    data.where(id: id).update(listen_count: listen_count, age_rating: age_rate)
    age_rate
  end

  def change_skip_rate
    old_rate = data[id: id][:skip_rating]
    new_rate = old_rate * (1 - skip_influence * (1 - skip_rate))
    data.where(id: id).update(skip_rating: new_rate)
    new_rate
  end

  def skip_rate
    new_time = mpd.stats[:playtime]
    elapsed_time = new_time - last_playtime
    @last_playtime = new_time
    time = mpd.songs[id].time
    elapsed_time.to_f / time
  end

  def initialize_playlist
    mpd.status[:playlistlength].times.each_slice(1000) do |slice|
      DB.transaction do
        slice.each do |x|
          data.insert(listen_count: 0, skip_rating: 1, age_rating: 1)
          mpd.song_priority(255, x)
        end
      end
    end
  end

  def track_priority
    loop do
      next_song = mpd.current_song.id
      (sleep 1; next) if next_song == id
      pid = Process.fork do
        change_priority
        @id = next_song
      end
      Process.waitpid pid
    end
  end
end
