require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(home_phone)
  home_phone.to_s.gsub!(/\D/, '')
  home_phone.length == 10 ? home_phone 
  : (home_phone.length == 11 && home_phone.start_with?('1') ? home_phone[1..] : '')
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
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

def check_peak_hours(reg_dates)
  hours = reg_dates.map { |date| Time.strptime(date, "%m/%d/%y %H:%M").hour}
  peak_hour_count = hours.tally.max_by { |_, count| count }[1]
  peak_hours = hours.tally.select { |_, count| count == peak_hour_count }.keys
  return "The peak registration hours are #{peak_hours.join(", ")}"
end

csv_file_path = 'event_attendees.csv'
erb_file_path = 'form_letter.erb'

puts 'Event Manager Initialized!'

if File.exist?(csv_file_path) and File.exist?(erb_file_path)
  contents = CSV.open(
    csv_file_path, 
    headers: true, 
    header_converters: :symbol
  )

  template_letter = File.read('form_letter.erb')
  erb_template = ERB.new template_letter

  reg_dates = Array.new

  contents.each do |row|
    id = row[0]
    name = row[:first_name]
    zipcode = clean_zipcode(row[:zipcode])
    legislators = legislators_by_zipcode(zipcode)

    form_letter = erb_template.result(binding)

    save_thank_you_letter(id, form_letter)

    reg_dates.push(row[:regdate])
  end

  peak_hours = check_peak_hours(reg_dates)
  puts peak_hours

else
  puts "File not found"
end

