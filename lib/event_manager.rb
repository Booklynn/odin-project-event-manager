# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(home_phone)
  home_phone.to_s.gsub!(/\D/, '')
  if home_phone.length == 10
    home_phone
  else
    home_phone.length == 11 && home_phone.start_with?('1') ? home_phone[1..] : ''
  end
end

def legislators_by_zipcode(zipcode)
  civic_info = initialize_civic_info
  fetch_representatives(civic_info, zipcode)
end

def initialize_civic_info
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip
  civic_info
end

def fetch_representatives(civic_info, zipcode)
  civic_info.representative_info_by_address(
    address: zipcode,
    levels: 'country',
    roles: %w[legislatorUpperBody legislatorLowerBody]
  ).officials
rescue StandardError
  'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def get_peak_hours(reg_dates)
  hours = reg_dates.map { |date| Time.strptime(date, '%m/%d/%y %H:%M').hour }
  peak_hour_count = hours.tally.max_by { |_, count| count }[1]
  hours.tally.select { |_, count| count == peak_hour_count }.keys
end

def display_peak_hours(reg_dates)
  peak_hours = get_peak_hours(reg_dates)
  puts "The peak registration hours: #{peak_hours.join(', ')}"
end

def get_most_days_of_week(reg_dates)
  days = reg_dates.map { |date| Date.strptime(date, '%m/%d/%y').wday }
  most_day_count = days.tally.max_by { |_, count| count }[1]
  days.tally.select { |_, count| count == most_day_count }.keys.map { |wday| Date::DAYNAMES[wday] }
end

def display_peak_days(reg_dates)
  most_days = get_most_days_of_week(reg_dates)
  puts "The days of the week most people register: #{most_days.join(', ')}"
end

csv_file_path = 'event_attendees.csv'
erb_file_path = 'form_letter.erb'

puts 'Event Manager Initialized!'

if File.exist?(csv_file_path) && File.exist?(erb_file_path)
  contents = CSV.open(
    csv_file_path,
    headers: true,
    header_converters: :symbol
  )

  template_letter = File.read('form_letter.erb')
  erb_template = ERB.new template_letter

  reg_dates = []

  contents.each do |row|
    id = row[0]
    name = row[:first_name]
    zipcode = clean_zipcode(row[:zipcode])
    legislators = legislators_by_zipcode(zipcode)
    reg_dates.push(row[:regdate])

    form_letter = erb_template.result(binding)

    save_thank_you_letter(id, form_letter)
  end

  display_peak_hours(reg_dates)
  display_peak_days(reg_dates)

else
  puts 'File not found'
end
