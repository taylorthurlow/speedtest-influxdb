#!/usr/bin/env ruby

require "json"
require "influxdb"

# @return [String]
def option_string
  server_id = ENV.fetch("SPEEDTEST_SERVER_ID") do
    warn "No speedtest server ID provided. Please set the SPEEDTEST_SERVER_ID environment variable."
    exit 1
  end
  
  [
    "--accept-license",
    "--format=json",
    "--precision=8",
    "--server-id=#{server_id}",
  ].join(" ")
end

# @return [Hash] the resulting JSON from the call to speedtest
def run_test
  json_result = `speedtest #{option_string}`

  unless $?.success?
    warn "Call to speedtest returned non-zero exit code: #{$?.exitstatus}"
    exit 1
  end

  begin
    JSON.parse(json_result)
  rescue JSON::ParserError => e
    warn "Failed to parse JSON response: #{e.message}"
    warn "=========="
    warn json_result
    warn "=========="
    exit 1
  end
end

# @param data [Hash] the hashified JSON result from the speedtest CLI
#
# @return [Boolean] true if successful
def send_to_influx(data)
  username = ENV["INFLUXDB_USERNAME"]
  username = nil if username.blank?
  password = ENV["INFLUXDB_PASSWORD"]
  password = nil if password.blank?

  client = InfluxDB::Client.new(
    ENV.fetch("INFLUXDB_DATABASE", "speedtest"),
    host: ENV.fetch("INFLUXDB_HOST", "localhost"),
    port: ENV.fetch("INFLUXDB_PORT", "8086"),
    username: username,
    password: password,
  )

  data = {
    values: {
      download: data["download"]["bandwidth"],
      upload: data["upload"]["bandwidth"],
      ping: data["ping"]["latency"],
      jitter: data["ping"]["jitter"],
      server: data["server"]["id"],
      server_name: data["server"]["name"],
      result_id: data["result"]["id"],
      result_url: data["result"]["url"],
    },
    tags: {
      server: data["server"]["id"],
      server_name: data["server"]["name"],
      server_location: data["server"]["location"],
      server_country: data["server"]["country"],
    },
  }
  
  puts "Sending new data to InfluxDB:"
  puts JSON.pretty_generate(data)
  client.write_point("speed_test_results", data)
end

loop do
  send_to_influx(run_test)

  # Sleep 1 hour by default
  sleep(ENV.fetch("INTERVAL_IN_SECONDS", 3600).to_i)
end
