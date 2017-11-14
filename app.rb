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
  Geocoder.coordinates(params[:place]).to_json
end

post '/next_travel' do
  res = Net::HTTP.get('carte-tgvmax.sncf.com', "/stations.json")
  stations = JSON.parse(res)['features']

  today = Date.today
  res = Net::HTTP.get('carte-tgvmax.sncf.com', "/travels/#{today.strftime("%d-%m-%Y")}.json")
  travels = JSON.parse(res)

  originStation = searchClosestStation([params[:lat], params[:lon]], stations)

  next_travels = travels
    .select do |t|
      t['originStationId'] == originStation['id'] && t['odHP'] == '1' && currentTime < Time.parse(t['startTime'])
    end
    .sort_by { |t| [Time.parse(t['startTime']), currentTime - Time.parse(t['endTime'])] }

  if next_travels.empty?
    "Plus de train libre aujourd'hui 😞"
  else
    #"Prochain train depuis #{stationDeparture['name']} à destination de #{stationDestination['name']}, départ aujourd'hui à #{timeDeparture.strftime("%H:%M")}"
    formatTravels(next_travels, stations).to_json
  end
end

private
def searchClosestStation(originCoord, stations)
  userPlace = [originCoord[0], originCoord[1]]
  stations.sort_by do |s|
    stationPlace = [s['geometry']['coordinates'][1], s['geometry']['coordinates'][0]]
    Geocoder::Calculations.distance_between(userPlace, stationPlace)
  end.first
end

def currentTime
  Time.now.utc.localtime("+01:00")
end

def formatTravels(travels, stations)
  travels.map do |travel|
    timeDeparture = DateTime.parse("#{travel['date']} #{travel['startTime']}")

    originStation      = searchStation(travel['originStationId'], travel['originAsText'], stations)
    destinationStation = searchStation(travel['destinationStationId'], travel['destinationAsText'], stations)
    {
      datetime: timeDeparture,
      originStation: {
        id: originStation['id'],
        name: originStation['name']
      },
      destinationStation: {
        id: destinationStation['id'],
        name: destinationStation['name']
      }
    }
  end
end

# Certains stations aren't in the file stations.json
def searchStation(station_id, station_text, stations)
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
