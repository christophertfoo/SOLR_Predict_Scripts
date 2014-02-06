def load_csv(path, options = {})
  options = { :extra_headers => false, :data => {} }.merge(options)
  data = options[:data]
  puts "Loading #{path}..."
  file = File.open(path, "r")
  headers = read_csv_line(file)
  2.times { read_csv_line(file) } if options[:extra_headers]
  while line = read_csv_line(file)
    raise "Number of columns does not match.  Expected: #{headers.count}, Actual: #{line.count}" if headers.count != line.count
    row = {}
    for i in 0...headers.count
      row[headers[i].to_sym] = line[i]
    end
    data[:data] = [] if data[:data].nil?
    data[:data].push(row)
  end
  return {:headers => headers, :data => data[:data]}
end

def load_header_csv(path)
  puts "Loading #{path}..."
  file = File.open(path, "r")
  headers = {}
  while line = read_csv_line(file)
    raise "Number of columns does not match.  Expected: 3, Actual: #{line.count}" if 3 != line.count
    row = {}
    headers[line[0].to_sym] = { :description => line[1], :unit => line[2] }
  end
  headers = headers.merge({
    :E_SATURATED => { :description => "Saturation Vapor Pressure", :unit =>  "hPa" },
    :E_ACTUAL => { :description => "Actual Vapor Pressure", :unit =>  "hPa" },
    :SKNT_E => { :description => "Wind Velocity in the East Direction", :unit =>  "mph" },
    :SKNT_N => { :description => "Wind Velocity in the North Direction", :unit =>  "mph" },
    :PEAK_E => { :description => "Peak Wind Velocity in the East Direction", :unit =>  "mph" },    
    :PEAK_N => { :description => "Peak Wind Velocity in the North Direction", :unit =>  "mph" },
    :GUST_E => { :description => "Gust Wind Velocity in the East Direction", :unit =>  "mph" },    
    :GUST_N => { :description => "Gust Wind Velocity in the North Direction", :unit =>  "mph" },
    :TTD => { :description => "Difference between Temperature and Dew Point", :unit => "degrees F" },
    :DWPF => { :description => "Dew Point", :unit => "degrees F" },
    :RELH_CALCULATED => { :description => "Calculated Relative Humidity", :unit => "%" },
    :RELH_ERROR => { :description => "Error between observed and calculated relative humidity", :unit => "%" },
    :RELH_REL_ERROR => { :description => "Relative Error between observed and calculated relative humidity", :unit => "" }
  })
  return(headers)
end

def read_csv_line(file)
  line = file.gets()
  line = line.strip.split(',', -1) if !line.nil?
end

def load_source(path, options={})
  options ={:merged_suffix => "", :suffix => "[0-9][0-9][0-9][0-9]", :write_merged => false, :load_merged => true}.merge(options)
  data = {}
  files = []  
  extra_headers = false
  files = Dir.glob("merged/#{path}#{options[:merged_suffix]}.csv") if options[:load_merged]  
  if files.count == 0
    files = Dir.glob("#{path}/*-#{options[:suffix]}.csv") 
  else
    extra_headers = true
  end
  
  files.each do |file|
    data = load_csv("#{file}", :data => data, :extra_headers => extra_headers) 
  end
  data[:data].each do |entry|
    entry[:DATE_TIME] = Time.new(entry[:YEAR], entry[:MON], entry[:DAY], entry[:HR], entry[:MIN])
  end
  data[:data] = data[:data].sort_by! { |datum| datum[:DATE_TIME] }
  if options[:write_merged]
    if !Dir.exists? 'merged'
      Dir.mkdir 'merged'
    end
    write_csv("merged/#{path}.csv", data)
  end
  return data
end

def write_csv(path, data, options={})
  options = { :write_info => false }.merge(options)
  keys = data[:headers].map do |header| header.to_sym end
  
  file = File.open(path, "w")
  file.write("#{keys.join(',')}\n")
  
  if options[:write_info]
    headers_join = load_header_csv('headers.csv')
    descriptions = []
    units = []
    keys.each do |key|
      info = headers_join[key]
      if info.nil?
        descriptions.push('')
        units.push('')
      else
        descriptions.push(headers_join[key][:description])
        units.push(headers_join[key][:unit])
      end
    end
    file.write("#{descriptions.join(',')}\n")
    file.write("#{units.join(',')}\n")
  end
  data[:data].each do |row|
    row_data = []
    keys.each do |key|
      row_data.push(row[key])
    end
    file.write("#{row_data.join(',')}\n")
  end
  file.close
end