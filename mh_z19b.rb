require 'serialport'

class MH_Z19B
  def initialize(device_name, baud_rate = 9600, data_bits = 8, stop_bits = 1, parity = 0)
    @device_name = device_name
    @baud_rate = baud_rate
    @data_bits = data_bits
    @stop_bits = stop_bits
    @parity = parity
  end

  def read_CO2_concentration
    response = nil
    SerialPort.open(@device_name, @baud_rate, @data_bits, @stop_bits, @parity) do |serial|
      serial.break(1)
      serial.flush_input
      serial.flush_output
      serial.puts("\xFF\x01\x86\x00\x00\x00\x00\x00\x79")
      # response = serial.readline.chomp.strip
      response = serial.gets(9)
    end
    raise if response.empty?
    response_bytes = response.unpack('C9')
    raise unless checksum(response_bytes) == response_bytes[8]
    {
      co2: response_bytes[2] * 256 + response_bytes[3],
      temperature: (response_bytes[4] - 40),
    }
  end

  def zero_point_calibration
    SerialPort.open("/dev/ttyAMA0", 9600, 8, 1, 0) do |serial|
      serial.flush_input
      serial.flush_output
      serial.puts("\xFF\x01\x87\x00\x00\x00\x00\x00\x78")
    end
  end

  private

  def checksum(bytes)
    sum = bytes[1..7].reduce(&:+)
    sum = sum & 0xff  # 下位8bitで確認
    (0xff - sum) + 1  # 0xff: 1の補数を使ってビット反転
  end
end
