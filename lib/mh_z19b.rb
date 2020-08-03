require 'serialport'

class Mh_z19b
  def initialize(device_name, baud_rate = 9600, data_bits = 8, stop_bits = 1, parity = 0)
    @device_name = device_name
    @baud_rate = baud_rate
    @data_bits = data_bits
    @stop_bits = stop_bits
    @parity = parity
  end

  def read_CO2_concentration
    try_count = 0
    begin
      received_data = nil
      SerialPort.open(@device_name, @baud_rate, @data_bits, @stop_bits, @parity) do |serial|
        serial.read_timeout = 1000
        serial.flush_input
        serial.flush_output
        puts "#{Time.now}: MH_Z19B read_CO2_concentration request start..."
        serial.puts("\xFF\x01\x86\x00\x00\x00\x00\x00\x79")
        puts "#{Time.now}: MH_Z19B read_CO2_concentration request finished successfully!"
        sleep 2
        puts "#{Time.now}: MH_Z19B read_CO2_concentration response start..."
        received_data = serial.gets(9)
        puts "#{Time.now}: MH_Z19B read_CO2_concentration response finished successfully!"
      end
      raise if received_data.empty?
      received_bytes = received_data.unpack('C10')
      response = if checksum(received_bytes) == received_bytes[8]
                   received_bytes
                 elsif checksum(received_bytes[1..9]) == received_bytes[9]
                   $stderr.puts "#{Time.now}: Received unstable data: #{received_bytes}"
                   received_bytes[1..９]
                 else
                   $stderr.puts "#{Time.now}: Received unknown data: #{received_bytes}"
                   raise received_bytes.to_s
                 end
    rescue => exception
      try_count += 1
      $stderr.puts "#{Time.now}: exception: #{exception}, try count: #{try_count}"
      (sleep(1) && retry) if try_count < 7
    end
    {
      co2: response[2] * 256 + response[3],
      temperature: (response[4] - 40),
    }
  end

  def zero_point_calibration
    SerialPort.open("/dev/ttyAMA0", 9600, 8, 1, 0) do |serial|
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
