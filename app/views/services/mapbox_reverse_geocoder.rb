class MapboxReverseGeocoder
  def self.lookup(lat, lng)
    token = ENV["MAPBOX_PUBLIC_TOKEN"]
    url = "https://api.mapbox.com/geocoding/v5/mapbox.places/#{lng},#{lat}.json?access_token=#{token}"

    response = Net::HTTP.get(URI(url))
    data = JSON.parse(response)

    data.dig("features", 0, "place_name")
  rescue
    nil
  end
end
