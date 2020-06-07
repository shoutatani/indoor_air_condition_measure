require 'i2c/bme280'

class Bme280
  def initialize(device_no: 1)
    @device = I2C::Driver::BME280.new(device: device_no)
  end

  def value
    puts "#{Time.now}: BME280 temperature, pressure, humidity request & response start..."
    measured_value = {
      temperature: @device.temperature.round(2),
      pressure: @device.pressure.round(2),
      humidity: @device.humidity.round(2)
    }
    puts "#{Time.now}: BME280 temperature, pressure, humidity request & response finished successfully!"
    measured_value
  end
end
