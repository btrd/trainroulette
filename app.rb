require 'net/http'
require 'json'
require 'time'
require 'geocoder'
require 'sinatra'
require 'slim'

if development?
  require 'sinatra/reloader'
  require 'pry'
end

before do
  if settings.production? && request.scheme == 'http'
    headers['Location'] = request.url.sub('http', 'https')
    halt 301, "https required\n"
  end
end

get '/' do
  slim :index
end

post '/get_coordinates' do
  coord = Geocoder.coordinates(params[:place])
  if coord.nil?
    status 404
  else
    coord.to_json
  end
end

post '/next_travel' do
  res = Net::HTTP.get('carte-tgvmax.sncf.com', '/stations.json')
  stations = JSON.parse(res)['features']

  today = Date.today
  res = Net::HTTP.get('carte-tgvmax.sncf.com', "/travels/#{today.strftime('%d-%m-%Y')}.json")
  travels = JSON.parse(res)

  origin_station = search_closest_station([params[:lat], params[:lon]], stations)

  next_travels = travels
                 .select do |t|
                   t['originStationId'] == origin_station['id'] && t['odHP'] == '1' && current_time < Time.parse(t['startTime'])
                 end
                 .sort_by { |t| [Time.parse(t['startTime']), current_time - Time.parse(t['endTime'])] }

  if next_travels.empty?
    "Plus de train libre aujourd'hui 😞"
  else
    format_travels(next_travels, stations).to_json
  end
end

private
def search_closest_station(origin_coord, stations)
  user_place = [origin_coord[0], origin_coord[1]]
  stations.sort_by do |s|
    station_place = [s['geometry']['coordinates'][1], s['geometry']['coordinates'][0]]
    Geocoder::Calculations.distance_between(user_place, station_place)
  end.first
end

def current_time
  Time.now.utc.localtime('+01:00')
end

def format_travels(travels, stations)
  travels.map do |travel|
    time_departure = DateTime.parse("#{travel['date']} #{travel['startTime']}")

    origin_station      = search_station(travel['originStationId'], travel['originAsText'], stations)
    destination_station = search_station(travel['destinationStationId'], travel['destinationAsText'], stations)
    {
      datetime: time_departure,
      originStation: {
        id: origin_station['id'],
        name: origin_station['name']
      },
      destinationStation: {
        id: destination_station['id'],
        name: destination_station['name']
      }
    }
  end
end

# Certains stations aren't in the file stations.json
def search_station(station_id, station_text, stations)
  station = stations.find { |s| s['id'] == station_id }
  if station.nil?
    {
      'id' => station_id,
      'name' => station_text
    }
  else
    station
  end
end
