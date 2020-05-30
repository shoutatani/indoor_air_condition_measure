require 'aws-sdk-s3'
require "csv"
require 'fileutils'
require 'i2c/bme280'
require 'json'
require './mh_z19b'
require 'faraday'

now = Time.now

begin
  bme280_current_measurement_value = I2C::Driver::BME280.new(device: 1)
  temperature = bme280_current_measurement_value.temperature.round(2)
  pressure = bme280_current_measurement_value.pressure.round(2)
  humidity = bme280_current_measurement_value.humidity.round(2)
  puts "#{now}: temperature: #{temperature}, pressure: #{pressure}, humidity: #{humidity}"
rescue => exception
  puts "#{now}:BME280 #{exception}"
  raise
end

begin
  mh_z19b = MH_Z19B.new("/dev/ttyAMA0", 9600, 8, 1, 0)
  mh_z19b_calc_data = mh_z19b.read_CO2_concentration
  co2_concentration = mh_z19b_calc_data[:co2]
  # temperature = mh_z19b_calc_data[:temperature]
  puts "#{now}: mh_z19b_calc_data: #{mh_z19b_calc_data}, co2_concentration: #{co2_concentration}"
rescue => exception
  puts "#{now}:MH_Z19B #{exception}"
  raise
end

log_file_name = "#{now.strftime("%Y%m%d")}.csv"
log_file_directory = File.expand_path("./log/#{now.year}/#{now.strftime("%m")}", __dir__)

log_file_location = "#{log_file_directory}/#{log_file_name}"
puts "#{now}: #{log_file_location}"

unless File.exists?(log_file_location)
  FileUtils.mkdir_p(log_file_directory)
  CSV.open(log_file_location, "wb", force_quotes: true) do |row|
    row << [
      "measuring_time",
      "temperature",      # C
      "pressure",         # hPa
      "humidity",         # percentage
      "co2_concentration" # ppm
    ]
  end
end

CSV.open(log_file_location, "a", force_quotes: true) do |row|
  row << [
    now.strftime("%Y-%m-%d %H:%M:%S"),
    temperature,
    pressure,
    humidity,
    co2_concentration
  ]
end

s3 = Aws::S3::Resource.new(region: 'ap-northeast-1')
obj = s3.bucket('iot.tan-shio.com').object("log/indoor_environment/#{now.year}/#{now.strftime("%m")}/#{log_file_name}")
obj.upload_file(log_file_location)

# push to all
# POST 'application/x-www-form-urlencoded' content
slack_url = ENV["SLACK_INDOOR_AIR_CANNEL"]
# POST JSON content

def notify_slack(slack_url, co2_concentration, temperature, pressure, humidity, time)
  puts "faraday start"
  result = Faraday.post(
    slack_url,
    {text: "
    *******************************************
    CO2: #{co2_concentration} ppm\n
    Temperature: #{temperature} 度\n
    Pressure: #{pressure} hPa\n
    Humidity: #{humidity} %\n
    at #{time.strftime("%Y-%m-%d %H:%M:%S")}
    "}.to_json,
    "Content-Type" => "application/json"
  )
  puts "faraday end: #{result.inspect}"
end

notify_slack(slack_url, co2_concentration, temperature, pressure, humidity, now)
# resp = Faraday.post(
#   slack_url,
#   {text: "
#   *******************************************
#   CO2: #{co2_concentration} ppm\n
#   Temperature: #{temperature} 度\n
#   Pressure: #{pressure} hPa\n
#   Humidity: #{humidity} %\n
#   at #{now.strftime("%Y-%m-%d %H:%M:%S")}
#   "}.to_json,
#   "Content-Type" => "application/json"
# )

if co2_concentration >= 1000
  # POST 'application/x-www-form-urlencoded' content
  slack_url = ENV['SLACK_INDOOR_CO2_CANNEL']

  # POST JSON content
  resp = Faraday.post(
    slack_url,
    {text: "CO2: #{co2_concentration} ppm at #{now.strftime("%Y-%m-%d %H:%M:%S")}"}.to_json,
    "Content-Type" => "application/json"
  )
end

