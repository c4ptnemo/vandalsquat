# app/services/mapbox_reverse_geocoder.rb
require "net/http"
require "json"

class MapboxReverseGeocoder
  def self.lookup(latitude, longitude)
    token = ENV["MAPBOX_PUBLIC_TOKEN"]
    return nil if token.nil? || token.strip.empty?
    return nil if latitude.nil? || longitude.nil?

    lat = latitude.to_f
    lng = longitude.to_f

    url = URI("https://api.mapbox.com/geocoding/v5/mapbox.places/#{lng},#{lat}.json?access_token=#{token}&limit=1")

    res = Net::HTTP.get_response(url)
    return nil unless res.is_a?(Net::HTTPSuccess)

    data = JSON.parse(res.body)
    data.dig("features", 0, "place_name")
  rescue
    nil
  end
end
