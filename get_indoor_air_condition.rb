require 'aws-sdk-s3'
require "csv"
require 'fileutils'
require 'i2c/bme280'
require 'json'

bme280_current_measurement_value = I2C::Driver::BME280.new(device: 1)

now = Time.now
log_file_name = "#{now.strftime("%Y%m%d")}.csv"
log_file_directory = File.expand_path("./log/#{now.year}/#{now.strftime("%m")}", __dir__)

log_file_location = "#{log_file_directory}/#{log_file_name}"
puts log_file_location

unless File.exists?(log_file_location)
  FileUtils.mkdir_p(log_file_directory)
  CSV.open(log_file_location, "wb", force_quotes: true) do |row|
    row << [
      "measuring_time",
      "temperature",    # C
      "pressure",       # hPa
      "humidity"        # percentage
    ]
  end
end

CSV.open(log_file_location, "a", force_quotes: true) do |row|
  row << [
    Time.now.strftime("%Y-%m-%d %H:%M:%S"),
    bme280_current_measurement_value.temperature.round(2),
    bme280_current_measurement_value.pressure.round(2),
    bme280_current_measurement_value.humidity.round(2)
  ]
end

s3 = Aws::S3::Resource.new(region: 'ap-northeast-1')
obj = s3.bucket('iot.tan-shio.com').object("log/indoor_environment/#{now.year}/#{now.strftime("%m")}/#{log_file_name}")
obj.upload_file(log_file_location)
