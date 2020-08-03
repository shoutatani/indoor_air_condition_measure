require 'aws-sdk-s3'
require "csv"
require 'fileutils'
require 'json'
require './lib/bme280'
require './lib/mh_z19b'
require 'faraday'

class IndoorAirMeasure
  attr_reader :executed_time

  def execute
    @executed_time = Time.now

    bme280_measured_value = retrive_bme280_measured_value
    mh_z19b_measured_value = retrive_mh_z19b_measured_value

    measured_value = bme280_measured_value.merge(mh_z19b_measured_value)

    save_log(measured_value)
    notify_slack_channels(measured_value)
  end

  private

  def retrive_bme280_measured_value
    bme280 = Bme280.new
    begin
      bme280_response = bme280.value
      temperature = bme280_response[:temperature]
      humidity = bme280_response[:humidity]
      pressure = bme280_response[:pressure]
    rescue => exception
      temperature = humidity = pressure = 0
    end
    puts "#{Time.now}: temperature: #{temperature}, pressure: #{pressure}, humidity: #{humidity}"
    {
      temperature: temperature,
      humidity: humidity,
      pressure: pressure,
    }
  end

  def retrive_mh_z19b_measured_value
    mh_z19b = Mh_z19b.new("/dev/ttyAMA0", 9600, 8, 1, 0)
    begin
      mh_z19b_response = mh_z19b.read_CO2_concentration
      co2_concentration = mh_z19b_response[:co2]
    rescue => exception
      $stderr.puts "Error!: #{exception}"
      co2_concentration = 0
    end
    puts "#{Time.now}: co2_concentration: #{co2_concentration}"
    {
      co2_concentration: co2_concentration
    }
  end

  def save_log(measured_value)
    log_file_name = "#{executed_time.strftime("%Y%m%d")}.csv"
    log_file_directory = File.expand_path("./log/#{executed_time.year}/#{executed_time.strftime("%m")}", __dir__)
    
    log_file_path = "#{log_file_directory}/#{log_file_name}"    
    unless File.exists?(log_file_path)
      FileUtils.mkdir_p(log_file_directory)
      CSV.open(log_file_path, "wb", force_quotes: true) do |row|
        row << [
          "measuring_time",
          "temperature",      # C
          "pressure",         # hPa
          "humidity",         # percentage
          "co2_concentration" # ppm
        ]
      end
    end
    
    CSV.open(log_file_path, "a", force_quotes: true) do |row|
      row << [
        executed_time.strftime("%Y-%m-%d %H:%M:%S"),
        measured_value[:temperature],
        measured_value[:pressure],
        measured_value[:humidity],
        measured_value[:co2_concentration]
      ]
    end

    upload_log_to_s3(log_file_name, log_file_path)
  end

  def upload_log_to_s3(log_file_name, log_file_path)
    s3 = Aws::S3::Resource.new(region: 'ap-northeast-1')
    s3_object_path = "log/indoor_environment/#{executed_time.year}/#{executed_time.strftime("%m")}/#{log_file_name}"
    s3_object = s3.bucket(ENV['S3_LOG_BUCKET']).object(s3_object_path)
    s3_object.upload_file(log_file_path)
  end

  def notify_slack_channels(measured_value)
    notify_slack_air_channel(measured_value)
    notify_slack_co2_channel(measured_value)
  end

  def notify_slack_air_channel(measured_value)
    air_channel_url = ENV["SLACK_INDOOR_AIR_CANNEL"]
    return unless air_channel_url

    puts "#{Time.now}: post slack on air_channel start..."
    post_result = Faraday.post(
      air_channel_url,
      {text: "
      *******************************************
      CO2: #{measured_value[:co2_concentration]} ppm\n
      Temperature: #{measured_value[:temperature]} 度\n
      Pressure: #{measured_value[:pressure]} hPa\n
      Humidity: #{measured_value[:humidity]} %\n
      at #{executed_time.strftime("%Y-%m-%d %H:%M:%S")}
      "}.to_json,
      "Content-Type" => "application/json"
    )
    puts "#{Time.now}: post slack on air_channel finished successfully!"
    puts "#{Time.now}: #{post_result.inspect}"
  end

  def notify_slack_co2_channel(measured_value)
    co2_channel_url = ENV['SLACK_INDOOR_CO2_CANNEL']
    return unless co2_channel_url
    return unless measured_value[:co2_concentration] >= 1000

    puts "#{Time.now}: post slack on co2_channel start..."
    post_result = Faraday.post(
      co2_channel_url,
      {text: "CO2: #{measured_value[:co2_concentration]} ppm at #{executed_time.strftime("%Y-%m-%d %H:%M:%S")}"}.to_json,
      "Content-Type" => "application/json"
    )
    puts "#{Time.now}: post slack on co2_channel finished successfully!"
    puts "#{Time.now}: #{post_result.inspect}"
  end

end

measure = IndoorAirMeasure.new
measure.execute
