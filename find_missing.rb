require_relative('csv')
require_relative('pentad')

def split_into_pentads(missing)
  split = {}
  missing.each do |time, missing_cols|
    pentad = find_pentad(time)
    split[pentad] = {} if split[pentad].nil?
    split[pentad][time] = missing_cols
  end
  return split
end

def split_by_interval(missing)
  split = {}
  missing.each do |time, missing_cols|
    hour = { :MON => time[:MON], :DAY => time[:DAY], :HOUR => time[:HOUR], :MIN => time[:MIN] }
    split[hour] = [] if split[hour].nil?
    split[hour].push(missing_cols)
  end
  return split
end

def find_missing_column(data, options = {})
  options = { :starting_time => Time.new(2010, 1, 1), :ending_time => Time.new(2013, 12, 31, 23), :interval => 60 * 60 }
  missing = {}
  num_rows = data[:data].count
  current_time = options[:starting_time]
  i = 0
  while current_time != options[:ending_time]
    unless current_time.month == 2 && current_time.day == 29
      row = data[:data][i]
      if row[:YEAR].to_i != current_time.year || row[:MON].to_i != current_time.month || row[:DAY].to_i != current_time.day || row[:HR].to_i != current_time.hour || row[:MIN].to_i != current_time.min
        missing[{ :YEAR => current_time.year, :MON => current_time.month, :DAY => current_time.day, :HOUR => current_time.hour, :MIN => current_time.min }] = data[:headers].clone
      else
        missing_cols = []
        data[:headers].each do |col|
          missing_cols.push(col) if row[col.to_sym].strip.empty?
        end
        missing[{ :YEAR => current_time.year, :MON => current_time.month, :DAY => current_time.day, :HOUR => current_time.hour, :MIN => current_time.min }] = missing_cols if missing_cols.count > 0
        i += 1
      end
    end
    
    current_time += options[:interval]
  end
  return missing
end

def consecutive?(time1, time2, interval=3600)
  (Time.new(time2[:YEAR], time2[:MON], time2[:DAY], time2[:HOUR], time2[:MIN]) - Time.new(time1[:YEAR], time1[:MON], time1[:DAY], time1[:HOUR], time1[:MIN])).abs == interval
end

def find_gaps(missing, headers, interval=3600)
  gaps = {}
  headers.each do |header|
    gaps[header] = []
    times = sort_times(missing.select do |time, missing_cols|
      missing_cols.include?(header)
    end.keys)    
    i = 0
    num_times = times.count
    while i < num_times
      gap_start = times[i]
      gap_end = nil
      count = 1
      if i == num_times - 1
        gap_end = times[i]
      else
        while i < num_times - 1 && consecutive?(times[i], times[i + 1])
          count += 1
          i += 1
        end
        gap_end = times[i]
      end
      gaps[header].push({ :gap_start => gap_start, :gap_end => gap_end, :size => count * interval })
      i += 1
    end
  end
  return gaps
end

def write_raw(missing, name)
  Dir.mkdir 'missing_col_all' unless Dir.exists? 'missing_col_all'
  f = File.new("missing_col_all/#{name}.csv", "w")
  missing.each do |date, missing_cols|
    f.write("#{date[:YEAR]}-#{"%02d" % date[:MON]}-#{"%02d" % date[:DAY]} #{"%02d" % date[:HOUR]}:#{"%02d" % date[:MIN]},#{missing_cols.join(",")}\n")
  end
  f.close
end

def write_hourly(missing, headers, pentad_num, pentad_start, pentad_end, name, options={})
  options = { :total_day => 4, :interval => 3600 }.merge(options)
  puts "    Writing hourly data..."
  time = Time.new(2014, pentad_start[:MON], pentad_start[:DAY])
  end_time = Time.new(2014, pentad_end[:MON], pentad_end[:DAY], 23)
  f = File.new("missing_pentad/#{name}/#{name}-#{pentad_num}-hourly.csv", "w")
  f.write("TIME,COL,NUM_MISSING,PERCENT_MISSING\n") 
  
  interval = split_by_interval(missing)
  while time <= end_time     
    current_missing = interval[{ :MON => time.month, :DAY => time.day, :HOUR => time.hour, :MIN => time.min }]
    headers.each do |header|
      if current_missing.nil?
        missing_count = 0
      else
        missing_count = current_missing.reduce(0) do |count, row|
          if row.include?(header)
            count += 1 
          else
            count
          end
        end
      end
      f.write("#{"%02d" % time.month}-#{"%02d" % time.day} #{"%02d" % time.hour}:#{"%02d" % time.min},#{header},#{missing_count},#{missing_count / options[:total_day].to_f * 100}\n")
    end
    time += options[:interval]
    f.write("\n")
  end
  f.close
end

def write_pentad_missing(missing, headers, pentad_num, name, options={})
  options = { :total_pentad => 4 * 5 * 24 }.merge(options)
  
  puts "    Writing pentad data..."
  f = File.new("missing_pentad/#{name}/#{name}-#{pentad_num}-all.csv", "w")
  f.write("COL,NUM_MISSING,PERCENT_MISSING\n") 
  counts = missing.values.reduce({}) do |counts, row|
    row.each do |col|
      counts[col] = 0 if counts[col].nil?
      counts[col] += 1
    end
    counts
  end
  results = {}
  headers.each do |header|
    counts[header] = 0 if counts[header].nil?
    count = counts[header]
    percent = count / options[:total_pentad].to_f * 100
    results[header] = { :missing_count => count, :missing_percent => percent }
    f.write("#{header},#{count},#{count / options[:total_pentad].to_f * 100}\n")
  end
  f.close
  return results
end

def write_gaps(missing, headers, pentad_num, name)
  puts "    Writing gap data..."
  f = File.new("missing_pentad/#{name}/#{name}-#{pentad_num}-gaps.csv", "w")
  f.write("COL,NUM_GAPS,MEAN,STD_DEV\n") 
  gaps = find_gaps(missing, headers, 3600)
  results = {}
  headers.each do |header|
    current_gaps = gaps[header]
    mean = 0.0
    stddev = 0.0    
    if !current_gaps.nil?  && !current_gaps.empty?
      gap_sizes = current_gaps.collect { |gap| gap[:size] }
      mean = gap_sizes.reduce(:+) / gap_sizes.count.to_f
      stddev = Math.sqrt(gap_sizes.reduce(0) do |sum, count|
        sum += (count - mean) ** 2
      end / (gap_sizes.count == 1 ? 1.0 : (gap_sizes.count - 1).to_f))
    end
    mean /= 3600.0
    stddev /= 3600.0
    num_gaps = current_gaps.nil? ? 0 : current_gaps.count
    results[header] = { :gap_count => num_gaps, :mean_gap_length => mean, :gap_stddev => stddev }
    f.write("#{header},#{num_gaps},#{mean},#{stddev}\n")
  end
  f.close
  return results
end

def write_pentad(missing, headers, pentad_num, pentad_start, pentad_end, name, options={})
  Dir.mkdir 'missing_pentad' unless Dir.exists? 'missing_pentad'
  Dir.mkdir "missing_pentad/#{name}" unless Dir.exists? "missing_pentad/#{name}"
  
  write_hourly(missing, headers, pentad_num, pentad_start, pentad_end, name, options)
  pentad_result = write_pentad_missing(missing, headers, pentad_num, name, options)
  gap_result = write_gaps(missing, headers, pentad_num, name)
  result = pentad_result.merge(gap_result) do |key, pentad, gap|
    pentad.merge(gap)
  end
  return result
end

def sort_times(times, year=true)
  times.sort do |a, b|
    diff = 0
    diff = b[:YEAR] - a[:YEAR] if year
    diff = b[:MON] - a[:MON] if diff == 0
    diff = b[:DAY] - a[:DAY] if diff == 0
    diff = b[:HOUR] - a[:HOUR] if diff == 0
    diff = b[:MIN] - a[:MIN] if diff == 0
    diff
  end
end



# MAIN
pentads = generate_pentads

sources = Dir.glob('filtered/*')

sources.each do |source|
  name = source.match(/filtered\/(.+?)-filtered.csv/)[1]
  data = load_csv(source)
  puts "Finding missing columns..."
  missing = find_missing_column(data)
  puts "Writing raw data..."
  write_raw(missing, name)
  puts "Splitting into pentads..."
  pentad_split = split_into_pentads(missing)
  puts "Writing processed data..."
  i = 1
  results = {}
  pentad_split.each do |pentad, missing_data|
    puts "  Pentad #{i} / #{pentad_split.count}"
    pentad_range = pentads.select { |key, value| value == pentad }.keys.first
    results[pentad] = write_pentad(missing_data, data[:headers], pentad, pentad_range[:start],pentad_range[:end], name)
    i += 1
  end
  i = 1
  
  total_year = 4 * 365 * 24
  # Get missing counts for the whole data set
  puts "Getting overall counts..."
  counts = missing.values.reduce({}) do |counts, row|
    row.each do |col|
      counts[col] = 0 if counts[col].nil?
      counts[col] += 1
    end
    counts
  end
  missing_results = {}
  data[:headers].each do |header|
    counts[header] = 0 if counts[header].nil?
    count = counts[header]
    percent = count / total_year.to_f * 100
    missing_results[header] = { :missing_count => count, :missing_percent => percent }
  end
  
  # Get gaps for the whole data set
  puts "Getting overall gaps..."
  gaps = find_gaps(missing, data[:headers], 3600)
  gap_results = {}
  data[:headers].each do |header|
    current_gaps = gaps[header]
    mean = 0.0
    stddev = 0    
    if !current_gaps.nil?  && !current_gaps.empty?
      gap_sizes = current_gaps.collect { |gap| gap[:size] }
      mean = gap_sizes.reduce(:+) / gap_sizes.count.to_f
      stddev = Math.sqrt(gap_sizes.reduce(0) do |sum, count|
        sum += (count - mean) ** 2
      end / (gap_sizes.count == 1 ? 1.0 : (gap_sizes.count - 1).to_f))
    end
    mean /= 3600.0
    stddev /= 3600.0
    gap_results[header] = { :gap_count => current_gaps.nil? ? 0 : current_gaps.count, :mean_gap_length => mean, :gap_stddev => stddev }
  end
  
  # Write results to overall file
  threshold = 50
  remove_cols = []
  results[:overall] = missing_results.merge(gap_results) { |key, missing, gap| missing.merge(gap) }
  f = File.new("missing_pentad/#{name}/#{name}-overall.csv", "w")
  f.write("COL,Stat,Overall,#{(1..pentads.count).to_a.map { |pentad| "Pentad #{pentad}" }.join(',')}\n")
  data[:headers].each do |header|
    f.write("#{header},# Missing,#{results[:overall][header][:missing_count]}")
    for i in 1..pentads.count
      f.write(",#{results[i].nil? ? 0 : results[i][header][:missing_count]}")
    end
    f.write("\n")
    
    f.write(",% Missing,#{"%.02f" % results[:overall][header][:missing_percent]}")
    for i in 1..pentads.count
      f.write(",#{"%.02f" % (results[i].nil? ? 0 : results[i][header][:missing_percent])}")
    end
    f.write("\n")
    
    remove_cols.push(header) if results[:overall][header][:missing_percent] > threshold
    
    f.write(",# Gaps,#{results[:overall][header][:gap_count]}")
    for i in 1..pentads.count
      f.write(",#{results[i].nil? ? 0 : results[i][header][:gap_count]}")
    end
    f.write("\n")
    
    f.write(",Mean Gap (hr),#{"%.02f" % results[:overall][header][:mean_gap_length]}")
    for i in 1..pentads.count
      f.write(",#{"%.02f" % (results[i].nil? ? 0 : results[i][header][:mean_gap_length])}")
    end
    f.write("\n")
    
    f.write(",Gap Std Dev (hr),#{"%.02f" % results[:overall][header][:gap_stddev]}")
    for i in 1..pentads.count
      f.write(",#{"%.02f" % (results[i].nil? ? 0 : results[i][header][:gap_stddev])}")
    end
    f.write("\n\n")
  end
  f.close
  
  data[:headers] -= remove_cols
  Dir.mkdir('filtered-2') unless Dir.exists? 'filtered-2'
  write_csv("filtered-2/#{name}.csv", data)  
  puts
end