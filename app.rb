require 'net/http'
require 'json'
require 'time'
require 'geocoder'
require 'sinatra'
require "sinatra/reloader" if development?

get '/' do
  res = Net::HTTP.get('carte-tgvmax.sncf.com', "/stations.json")
  stations = JSON.parse(res)['features']

  today = Date.today
  res = Net::HTTP.get('carte-tgvmax.sncf.com', "/travels/#{today.strftime("%d-%m-%Y")}.json")
  travels = JSON.parse(res)

  def searchClosestStation(originCoord, stations)
    userPlace = [originCoord[0], originCoord[1]]
    srtSta = stations.sort_by do |s|
      stationPlace = [s['geometry']['coordinates'][1], s['geometry']['coordinates'][0]]
      Geocoder::Calculations.distance_between(userPlace, stationPlace)
    end.first
  end

  coordinates = Geocoder.coordinates('Paris')
  originStation = searchClosestStation(coordinates, stations)

  next_travel = travels.select { |t| t['originStationId'] == originStation['id'] && t['odHP'] == '1' }.sort_by { |t| [Time.parse(t['startTime']), Time.now - Time.parse(t['endTime'])] }.first

  timeDeparture = DateTime.parse("#{next_travel['date']} #{next_travel['startTime']}")

  stationDeparture   = stations.find { |s| s['id'] == next_travel['originStationId'] }
  stationDestination = stations.find { |s| s['id'] == next_travel['destinationStationId'] }

  "Prochain train depuis #{stationDeparture['name']} pour #{stationDestination['name']}, départ aujourd'hui à #{timeDeparture.strftime("%H:%M")}"
end
