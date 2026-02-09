# config/initializers/rack_attack.rb

class Rack::Attack
  # Throttle all requests by IP (prevent general DoS)
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  # Throttle login attempts by IP
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/login' && req.post?
      req.ip
    end
  end

  # Throttle signup attempts by IP
  throttle('signups/ip', limit: 3, period: 1.hour) do |req|
    if req.path == '/users' && req.post?
      req.ip
    end
  end

  # Throttle entry creation by IP
  throttle('entries/ip', limit: 20, period: 1.minute) do |req|
    if req.path.start_with?('/entries') && req.post?
      req.ip
    end
  end

  # Block requests from known bad IPs (optional - uncomment to use)
  # blocklist('block bad IPs') do |req|
  #   # Returns true if IP is in blocklist
  #   ['123.456.789.0', '111.222.333.444'].include?(req.ip)
  # end
end