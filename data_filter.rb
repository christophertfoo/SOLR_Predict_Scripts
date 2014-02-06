require 'bsearch'
require 'spliner'

def trim(data)
  data[:data] = [data[:data].first, data[:data].last]
  return data
end

def to_radians(degrees)
  degrees * Math::PI / 180
end

def remove_sparse_cols(data, min_percent=0.5)
  num_rows = data[:data].count
  
  missing_counts = {}
  for i in 0...num_rows
    data[:headers].each do |header|      
      if !data[:data][i][header.to_sym].strip.empty?
        if missing_counts[header].nil?
          missing_counts[header] = 1
        else
          missing_counts[header] += 1
        end
      end
    end
  end
  blank_columns = []
  missing_counts.each do |header, num_missing|
    if num_missing / num_rows.to_f < min_percent
      blank_columns.push(header)
    end
  end
  puts "Removing: #{blank_columns.inspect}"
  data[:headers] -= blank_columns
  return data
end

def threshold_solr(data, threshold = 10)
    num_rows = data[:data].count  
    for i in 0...num_rows
      data[:data][i][:SOLR] = "0" if !data[:data][i][:SOLR].strip.empty? && data[:data][i][:SOLR].to_f < 10
    end
    return data
end

def delta_prec(data)
  num_rows = data[:data].count 
  
  previous = data[:data].first[:PREC]
  for i in 1...num_rows
    if !data[:data][i][:PREC].strip.empty?
      previous = "0" if data[:data][i - 1][:PREC].strip.empty?
      difference = data[:data][i][:PREC].to_f - previous.to_f
      previous = data[:data][i][:PREC]
      data[:data][i][:PREC] = difference.to_s unless difference < 0        
    end
  end
  return data
end

def convert_wind_directions(data)
  if data[:headers].include?("DRCT") || data[:headers].include?("PDIR")
    num_rows = data[:data].count     
    for i in 0...num_rows
      unless data[:data][i][:DRCT].nil? || data[:data][i][:DRCT].strip.empty?
        data[:data][i][:DRCT] = (data[:data][i][:DRCT].to_f + 90) % 360
        data[:data][i][:DRCT] -= 360 if data[:data][i][:DRCT] > 180 
        data[:data][i][:DRCT] = data[:data][i][:DRCT].to_s
      end
      
      unless data[:data][i][:PDIR].nil? || data[:data][i][:PDIR].strip.empty?
        data[:data][i][:PDIR] = (data[:data][i][:PDIR].to_i + 90) % 360
        data[:data][i][:PDIR] -= 360 if data[:data][i][:PDIR] > 180 
        data[:data][i][:PDIR] = data[:data][i][:PDIR].to_s
      end
    end
  end
  return data
end

def convert_wind(data)
  if (include_sknt = data[:headers].include?("SKNT") || include_gust = data[:headers].include?("GUST"))&& data[:headers].include?("DRCT")  
    num_rows = data[:data].count     
    for i in 0...num_rows
      if data[:data][i][:DRCT].strip.empty?
        if include_sknt
          data[:data][i][:SKNT_E] = ""
          data[:data][i][:SKNT_N] = ""
        end
        if include_gust
          data[:data][i][:GUST_E] = ""
          data[:data][i][:GUST_N] = ""
        end
      else
        angle = to_radians(data[:data][i][:DRCT].to_f)
        if include_sknt
          if data[:data][i][:SKNT].nil? || data[:data][i][:SKNT].strip.empty?
            data[:data][i][:SKNT_E] = ""
            data[:data][i][:SKNT_N] = ""
          else
            magnitude = data[:data][i][:SKNT].to_f
            data[:data][i][:SKNT_E] = (-1 * magnitude * Math.sin(angle)).to_s
            data[:data][i][:SKNT_N] = (-1 * magnitude * Math.cos(angle)).to_s
          end
        end
        if include_gust
          if data[:data][i][:GUST].nil? || data[:data][i][:GUST].strip.empty?
            data[:data][i][:GUST_E] = ""
            data[:data][i][:GUST_N] = ""
          else
            magnitude = data[:data][i][:GUST].to_f
            data[:data][i][:GUST_E] = (-1 * magnitude * Math.sin(angle)).to_s
            data[:data][i][:GUST_N] = (-1 * magnitude * Math.cos(angle)).to_s
          end
        end
      end
    end
    data[:headers].push("SKNT_E", "SKNT_N") if include_sknt
    data[:headers].push("GUST_E", "GUST_N") if include_gust
  end
  return data
end

def convert_peak(data)
  num_rows = data[:data].count     
  for i in 0...num_rows
    if data[:data][i][:PDIR].strip.empty?
      data[:data][i][:PEAK_E] = ""
      data[:data][i][:PEAK_N] = ""
    else
      angle = to_radians(data[:data][i][:PDIR].to_f)
      if data[:data][i][:PEAK].nil? || data[:data][i][:PEAK].strip.empty?
        data[:data][i][:PEAK_E] = ""
        data[:data][i][:PEAK_N] = ""
      else
        magnitude = data[:data][i][:PEAK].to_f
        data[:data][i][:PEAK_E] = (-1 * magnitude * Math.sin(angle)).to_s
        data[:data][i][:PEAK_N] = (-1 * magnitude * Math.cos(angle)).to_s
      end
    end
  end
  data[:headers].push("PEAK_E", "PEAK_N")
  return data
end

def convert_ttd(data)
  if data[:headers].include?("TMPF") && data[:headers].include?("DWPF")
    num_rows = data[:data].count     
    for i in 0...num_rows
      if data[:data][i][:TMPF].nil? || data[:data][i][:TMPF].strip.empty? || data[:data][i][:DWPF].nil? || data[:data][i][:DWPF].strip.empty?
        data[:data][i][:TTD] = ""
      else
        data[:data][i][:TTD] = (data[:data][i][:TMPF].to_f - data[:data][i][:DWPF].to_f).to_s
      end
    end
    data[:headers].push("TTD")
  end
  return data
end

def e_sat(t)
  t0 = 273.15
  l = 2.5 * 10**6
  rv = 461
  tc = (5/9.0) * (t - 32)
  tk = tc + t0
  return 6.11 * Math.exp((l/rv) * ((1/t0) - (1/tk)))
end

def calculate_e_saturated(data)
  if data[:headers].include?("TMPF")
    num_rows = data[:data].count     
    for i in 0...num_rows
      if data[:data][i][:TMPF].nil? || data[:data][i][:TMPF].strip.empty? 
        data[:data][i][:E_SATURATED] = ""
      else
        data[:data][i][:E_SATURATED] = e_sat(data[:data][i][:TMPF].to_f).to_s
      end
    end
    data[:headers].push("E_SATURATED")
  end
  return data
end

def calculate_e_actual(data)
  if data[:headers].include?("DWPF")
    num_rows = data[:data].count     
    for i in 0...num_rows
      if data[:data][i][:DWPF].nil? || data[:data][i][:DWPF].strip.empty? 
        data[:data][i][:E_ACTUAL] = ""
      else
        data[:data][i][:E_ACTUAL] = e_sat(data[:data][i][:DWPF].to_f).to_s
      end
    end
    data[:headers].push("E_ACTUAL")
  end
  return data
end

def calculate_relh(data)
  if data[:headers].include?("E_ACTUAL") && data[:headers].include?("E_SATURATED")
    num_rows = data[:data].count
    for i in 0...num_rows
      if data[:data][i][:E_ACTUAL].nil? || data[:data][i][:E_ACTUAL].strip.empty? ||data[:data][i][:E_SATURATED].nil? || data[:data][i][:E_SATURATED].strip.empty? 
        data[:data][i][:RELH_CALCULATED] = ""
      else
        data[:data][i][:RELH_CALCULATED] = (100 * (data[:data][i][:E_ACTUAL].to_f / data[:data][i][:E_SATURATED].to_f)).to_s
      end
    end
    data[:headers].push("RELH_CALCULATED")
  end
  return data
end

def calculate_relh_error(data)
  if data[:headers].include?("TMPF") && data[:headers].include?("DWPF") && data[:headers].include?("RELH")
    num_rows = data[:data].count
    for i in 0...num_rows
      if data[:data][i][:RELH].nil? || data[:data][i][:RELH].strip.empty? ||data[:data][i][:RELH_CALCULATED].nil? || data[:data][i][:RELH_CALCULATED].strip.empty? 
        data[:data][i][:RELH_ERROR] = ""
        data[:data][i][:RELH_REL_ERROR] = ""
      else
        error = data[:data][i][:RELH_CALCULATED].to_f - data[:data][i][:RELH].to_f
        data[:data][i][:RELH_ERROR] = error.to_s
        data[:data][i][:RELH_REL_ERROR] = (error / data[:data][i][:RELH].to_f).to_s
      end
    end
    data[:headers].push("RELH_ERROR")
    data[:headers].push("RELH_REL_ERROR")
  end
  return data
end

def filter(data)
  delete_list = %w[FT QFLG]
  data[:headers] -= delete_list
  
  num_rows = data[:data].count  
  
  # Remove sparse columns
  data = remove_sparse_cols(data)
  
  # Threshold SOLR
  data = threshold_solr(data) if data[:headers].include?("SOLR")
  
  # Find TTD values
  data = convert_ttd(data)
  
  # Find specific humidity values
  data = calculate_e_saturated(data)
  data = calculate_e_actual(data)
  
  # Calculate RELH and the error
  data = calculate_relh(data)
  data = calculate_relh_error(data)
  
  # Delta PREC
  data = delta_prec(data)  if data[:headers].include?("PREC")

  # Convert Wind / Gust data
  data = convert_wind(data)
  
  # Convert Peak Wind data
  data = convert_peak(data) if data[:headers].include?("PEAK") && data[:headers].include?("PDIR")  

  # Convert Wind Directions
  data = convert_wind_directions(data)
  return data
end

def get_poll_interval(data)
  intervals = {}
  for i in 1...data[:data].count
    interval = data[:data][i][:DATE_TIME] - data[:data][i - 1][:DATE_TIME]
    if intervals[interval].nil?
      intervals[interval] = 1
    else
      intervals[interval] += 1
    end
  end
  mode = nil
  mode_count = nil
  intervals.each do |interval, count|
    if mode_count.nil? || count > mode_count
      mode = interval
      mode_count = count
    end    
  end
  data[:interval] = mode
  return data
end

def shift_times(data)
  data = get_poll_interval(data) if data[:interval].nil?
  interval = data[:interval] / 60
  half_interval = interval / 2
  
  # Shift each data point to the nearest expected point in time
  data_map = {}
  data[:data].each do |row|
    old_time = row[:DATE_TIME].clone
    mod = row[:DATE_TIME].min % interval
    if mod < half_interval
      row[:DATE_TIME] -= (mod * 60)
    else
      row[:DATE_TIME] += ((interval - mod) * 60)
    end
    row[:HR] = row[:DATE_TIME].hour
    row[:MIN] = row[:DATE_TIME].min
    row[:DAY] = row[:DATE_TIME].day
    row[:MON] = row[:DATE_TIME].month
    row[:YEAR] = row[:DATE_TIME].year
    row[:OLD_TIME] = old_time
    
    # Map each row by time to make finding duplicates faster
    data_map[row[:DATE_TIME]] = [] if data_map[row[:DATE_TIME]].nil?
    data_map[row[:DATE_TIME]].push(row)
  end
  
  ignore_columns = %w[MON DAY YEAR HR MIN TMZN]
  valid_columns = (data[:headers] - ignore_columns).map { |header| header.to_sym }
  final_data = []
  num_times = data_map.keys.count
  i = 1
  data_map.keys.sort!.each do |time|
    rows = data_map[time]
    if rows.count == 1
      final_data.push(rows.first)
    else
      result = nil
      if block_given?
        result = yield(rows, :valid_columns => valid_columns)
      else
        result = average_duplicates(rows, :valid_columns => valid_columns)
      end
      final_data.push(result)
    end
    puts "#{i} / #{num_times}"
    i += 1
  end
  data[:data] = final_data
  
  # Remove Feb 29
  data[:data].delete_if { |row| row[:MON].to_i == 2 && row[:DAY].to_i == 29 }
  
  data[:data] = data[:data].sort_by! { |datum| datum[:DATE_TIME] }
  return data
end

def average_duplicates(rows, options={})
  sums = {}
  counts = {}
  time = rows.first[:DATE_TIME]
  tmzn = rows.first[:TMZN]
  rows.each do |row|
    options[:valid_columns].each do |column|
      unless row[column].strip.empty?
        if sums[column].nil? 
          sums[column] = row[column].to_f
          counts[column] = 1
        else
          sums[column] += row[column].to_f
          counts[column] += 1
        end
      end
    end
  end
  average = {}
  sums.each do |key, value|
    average[key] = (value / counts[key]).to_s
  end
  average.merge!({ :YEAR => time.year, :MON => time.month, :DAY => time.day, :HR => time.hour, :MIN => time.min, :TMZN => tmzn, :DATE_TIME => time })
  (options[:valid_columns] - average.keys).each do |key|
    average[key] = ""
  end
  return average
end

def choose_closest(rows, options={})
  closest = nil
  closest_difference = nil
  rows.each do |row|
    if closest.nil?
      closest = row
    else
      diff = (row[:OLD_TIME] - row[:DATE_TIME]).abs
      if closest_diff.nil? || diff < closest_diff
        closest = row
        closest_diff = diff
      end
    end
  end
  return closest
end

def add_missing(data)
  data = get_poll_interval(data) if data[:interval].nil?
  interval = data[:interval]
  start_time = data[:data].first[:DATE_TIME]
  end_time = data[:data].last[:DATE_TIME]
  tmzn = data[:data].first[:TMZN]
  times = (data[:data].collect { |row| row[:DATE_TIME] }).sort
  empty_hash = {}
  data[:headers].each do |header|
    empty_hash[header.to_sym] = ""
  end
  
  while start_time != end_time
    if start_time.month != 2 && start_time.day != 29 && times.bsearch { |x| x <=> start_time }.nil?
      blank_row = empty_hash.clone
      blank_row[:YEAR] = start_time.year.to_s
      blank_row[:MON] = start_time.month.to_s
      blank_row[:DAY] = start_time.day.to_s
      blank_row[:HR] = start_time.hour.to_s
      blank_row[:MIN] = start_time.min.to_s
      blank_row[:TMZN] = tmzn
      blank_row[:DATE_TIME] = start_time.clone
      blank_row[:PENTAD] = find_pentad(:MON => start_time.month, :DAY => start_time.day) if data[:headers].include?("PENTAD")
      data[:data].push(blank_row)
    end
    start_time += interval
  end
  
  data[:data] = data[:data].sort_by! { |datum| datum[:DATE_TIME] }
  return data
end

# TODO Generalize to min?
def find_pentad_means(data)
  ignore_list = %w[YEAR MON DAY HR MIN PENTAD TMZN]
  data = set_pentads(data) unless data[:headers].include?("PENTAD")
  pentad_hash = {}
  data[:data].each do |row|
    pentad = row[:PENTAD]
    pentad_hash[pentad] = [] if pentad_hash[pentad].nil?
    pentad_hash[pentad].push(row)
  end
  
  means = {}
  valid_columns = (data[:headers] - ignore_list)
  
  pentad_hash.keys.each do |pentad|
    means[pentad] = {}
    rows = pentad_hash[pentad]
    rows.each do |row|  
      valid_columns.each do |header|
        means[pentad][header] = [] if means[pentad][header].nil?
        value = row[header.to_sym]
        hour = row[:HR].to_i
        unless value.strip.empty?
          if means[pentad][header][hour].nil?
            means[pentad][header][hour] = { :sum => value.to_f, :count => 1 }          
          else
            means[pentad][header][hour][:sum] += value.to_f
            means[pentad][header][hour][:count] += 1
          end
        end
      end
    end
    valid_columns.each do |header|
      (0..23).each do |i|
        if means[pentad][header][i].nil?
          means[pentad][header][i] = ""
        else
          means[pentad][header][i] = (means[pentad][header][i][:sum] / means[pentad][header][i][:count]).to_s
        end
      end
    end
  end
  return means
end

def find_gaps(data)
  ignore_list = %w[YEAR MON DAY HR MIN PENTAD TMZN]
  valid_columns = (data[:headers] - ignore_list)
  gaps = {}
  valid_columns.each do |header|
    gaps[header] = []
  end
  
  num_rows = data[:data].count
  for i in 0...num_rows
    time = data[:data][i][:DATE_TIME]
    valid_columns.each do |header|
      if data[:data][i][header.to_sym].strip.empty?
        if gaps[header].last.nil? || !gaps[header].last[:running]
          # Start of a new gap
          gaps[header].push( { :gap_indexes => [i], :running => true } ) 
        else
          # Add to running gap
          gaps[header].last[:gap_indexes].push(i)
        end
      else
        # Close running gap
        gaps[header].last[:running] = false if !gaps[header].last.nil? && gaps[header].last[:running]
      end
    end
  end
  return gaps
end

def fill_in_missing(data, options={})
  ignore_list = %w[YEAR MON DAY HR MIN PENTAD TMZN]
  valid_negative = %w[SKNT_E SKNT_N PEAK_E PEAK_N GUST_E GUST_N DRCT PDIR]
  generated_fields = %w[SKNT_E SKNT_N PEAK_E PEAK_N GUST_E GUST_N TTD E_SATURATED E_ACTUAL RELH_CALCULATED RELH_ERROR RELH_REL_ERROR]
  options = { :max_interpolation => 5, :max_adjacent => 2 }.merge(options)  
  valid_columns = (data[:headers] - ignore_list)
  pentad_means = find_pentad_means(data)
  gaps = find_gaps(data)
  last_index = data[:data].count - 1
  
  num_gaps = gaps.values.reduce(0) {|total, found_gaps| total += found_gaps.count}
  count = 1
  (gaps.keys - generated_fields).each do |header|
    header_sym = header.to_sym
    found_gaps = gaps[header]
    found_gaps.each do |gap|
      if gap[:gap_indexes].count > options[:max_interpolation] || gap[:gap_indexes].first == 0 || gap[:gap_indexes].last == last_index
        gap[:gap_indexes].each do |i|
          row = data[:data][i]
          data[:data][i][header_sym] = pentad_means[row[:PENTAD]][header][row[:HR].to_i]
          if pentad_means[row[:PENTAD]][header][row[:HR].to_i] == 0
            puts header
            puts row[:DATE_TIME]
          end
        end
      else
      
        # Gather data for spline
        sample_values = []   
        gap_start = gap[:gap_indexes].first
        gap_end = gap[:gap_indexes].last
        
        for j in 1..options[:max_adjacent]
          before = gap_start - j
          after = gap_end + j
          if before >= 0 && !data[:data][before][header_sym].strip.empty?
            sample_values.push({ :time => data[:data][before][:DATE_TIME].to_f, :value => data[:data][before][header_sym].to_f })
          end
          if after <= last_index && !data[:data][after][header_sym].strip.empty?
            sample_values.push({ :time => data[:data][after][:DATE_TIME].to_f, :value => data[:data][after][header_sym].to_f })
          end
        end
        
        sample_values = sample_values.sort_by! { |value| value[:time] }
        spline = Spliner::Spliner.new( sample_values.collect {|value| value[:time]}, sample_values.collect {|value| value[:value]} )
        
        # Interpolate using spline
        gap[:gap_indexes].each do |i|
          prediction = spline[data[:data][i][:DATE_TIME].to_f]
          prediction = 0 if prediction < 0 && !valid_negative.include?(header)
          prediction = 100 if header == "RELH" && prediction > 100
          data[:data][i][header_sym] = prediction.to_s
        end
      end
      
      puts "#{count} / #{num_gaps}"
      count += 1
    end
  end
   
  # Perform a sanity check on the generated DWPF values (must be <= TMPF)
  if gaps.keys.include?("TMPF") && gaps.keys.include?("DWPF")
    gaps["DWPF"].each do |gap|
      gap[:gap_indexes].each do |i|
        data[:data][i][:DWPF] = data[:data][i][:TMPF] if data[:data][i][:DWPF] > data[:data][i][:TMPF]
      end
    end
  end 
   
  # Fill in the generated fields
  (gaps.keys & generated_fields).each do |header|
    header_sym = header.to_sym
    found_gaps = gaps[header]
    case header
    when "SKNT_E"
      found_gaps.each do |gap|
        gap[:gap_indexes].each do |i|
          row = data[:data][i]
          angle = (row[:DRCT].to_f + 450) % 360
          data[:data][i][header_sym] = (-1 * row[:SKNT].to_f * Math.sin(to_radians(angle))).to_s
        end
      end
    when "SKNT_N"    
      found_gaps.each do |gap|
        gap[:gap_indexes].each do |i|
          row = data[:data][i]
          angle = (row[:DRCT].to_f + 450) % 360
          data[:data][i][header_sym] = (-1 * row[:SKNT].to_f * Math.cos(to_radians(angle))).to_s
        end
      end
    when "PEAK_E"
      found_gaps.each do |gap|
        gap[:gap_indexes].each do |i|
          row = data[:data][i]
          angle = (row[:PDIR].to_f + 450) % 360
          data[:data][i][header_sym] = (-1 * row[:PEAK].to_f * Math.sin(to_radians(angle))).to_s
        end
      end
    when "PEAK_N"
      found_gaps.each do |gap|
        gap[:gap_indexes].each do |i|
          row = data[:data][i]
          angle = (row[:PDIR].to_f + 450) % 360
          data[:data][i][header_sym] = (-1 * row[:PEAK].to_f * Math.cos(to_radians(angle))).to_s
        end
      end      
    when "GUST_E"
      found_gaps.each do |gap|
        gap[:gap_indexes].each do |i|
          row = data[:data][i]
          angle = (row[:DRCT].to_f + 450) % 360
          data[:data][i][header_sym] = (-1 * row[:GUST].to_f * Math.sin(to_radians(angle))).to_s
        end
      end
    when "GUST_N"
      found_gaps.each do |gap|
        gap[:gap_indexes].each do |i|
          row = data[:data][i]
          angle = (row[:DRCT].to_f + 450) % 360
          data[:data][i][header_sym] = (-1 * row[:GUST].to_f * Math.cos(to_radians(angle))).to_s
        end
      end
    when "TTD"
      found_gaps.each do |gap|
        gap[:gap_indexes].each do |i|
          row = data[:data][i]
          ttd = (row[:TMPF].to_f - row[:DWPF].to_f)
          ttd = 0 if ttd < 0
          data[:data][i][header_sym] = ttd.to_s
        end
      end
    when "E_SATURATED"
      found_gaps.each do |gap|
        gap[:gap_indexes].each do |i|
          row = data[:data][i]
          data[:data][i][header_sym] = e_sat(row[:TMPF].to_f).to_s
        end
      end
    when "E_ACTUAL"
      found_gaps.each do |gap|
        gap[:gap_indexes].each do |i|
          row = data[:data][i]
          data[:data][i][header_sym] = e_sat(row[:DWPF].to_f).to_s
        end
      end
    end
  end
  
  if gaps.keys.include?("RELH_CALCULATED")
    found_gaps = gaps["RELH_CALCULATED"]
    found_gaps.each do |gap|
        gap[:gap_indexes].each do |i|
          row = data[:data][i]
          data[:data][i][:RELH_CALCULATED] = (row[:E_ACTUAL].to_f / row[:E_SATURATED].to_f * 100).to_s
          data[:data][i][:RELH_ERROR] = (row[:RELH_CALCULATED].to_f - row[:RELH].to_f).to_s
          data[:data][i][:RELH_REL_ERROR] = (row[:RELH_ERROR].to_f / row[:RELH].to_f).to_s
        end
      end
  end
 
  return data
end