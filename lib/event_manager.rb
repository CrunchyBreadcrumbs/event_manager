require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phonenumber(phonenumber)
  phonenumber = phonenumber.to_s.tr("^0-9", "")
  if phonenumber.length == 10
    phonenumber
  elsif phonenumber.length == 11 && phonenumber.start_with?('1')
    phonenumber[1..10]
  else
    '0'
  end
end

def clean_date(reg_time)
  Time.strptime(reg_time, '%m/%d/%y %k:%M')
end

def peak_finder(arr)
  peak = Hash.new(0)

  arr.each do |value|
    peak[value] += 1
  end

  peak.max_by(&:last).first
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip

  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
registration_hour = Array.new
registration_day = Array.new

contents.each_with_index do |row, index|
  id = row[0]
  name = row[:first_name]
  phonenumber = clean_phonenumber(row[:homephone])
  reg_time = clean_date(row[:regdate])
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)

  registration_hour[index] = reg_time.hour
  registration_day[index] = reg_time.strftime('%A')

  # save_thank_you_letter(id, form_letter)
  # puts "#{phonenumber}"

end

puts "Peak Hour is: #{peak_finder(registration_hour)}"
puts "Peak Day is: #{peak_finder(registration_day)}"
