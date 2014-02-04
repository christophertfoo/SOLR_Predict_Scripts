require_relative 'global'
require_relative 'csv'
require_relative 'data_filter'
require_relative 'pentad'

def main
  min_year = 2010
  max_year = nil
  min_month = 1
  max_month = nil
  source_data = {}
  interval_data = {}
  $sources.each do |source|
    puts source
    data = load_source(source, :load_merged => false)
    data[:interval] = 3600
    puts "Filtering data..."
    data = filter(data)
    puts "Normalizing times..."
    data = shift_times(data)
    puts "Adding missing rows..."
    data = add_missing(data)
    puts "Filling in missing values..."
    data = fill_in_missing(data)
    if !Dir.exists? 'merged'
      Dir.mkdir 'merged'
    end
    puts "Writing merged data set to output file..."
    write_csv("merged/#{source}.csv", data)
    source_data[source.to_sym] = trim(data)
    puts
  end
  start_time = min_year ? Time.new(min_year, min_month || 1) : nil
  end_time = max_year ? Time.new(max_year, max_month || 12, 31, 23, 59, 59) : nil
  
  valid_sources = []
  source_data.each do |key, data|
    first = data[:data].first[:DATE_TIME]
    last = data[:data].last[:DATE_TIME]

    if (start_time.nil? || first <= start_time) && (end_time.nil? || last >= end_time)
      valid_sources.push(key.to_s)
    end
  end
  puts
  puts valid_sources.inspect
  puts "Kept #{valid_sources.count} / #{$sources.count} sources"
  puts
  
  valid_sources.each do |source|
    data = load_source(source)
    original_size = data[:data].count
    data[:data] = data[:data].keep_if do |datum|
      (start_time.nil? || datum[:DATE_TIME] >= start_time) && (end_time.nil? || datum[:DATE_TIME] <= end_time)
    end
    puts "Kept #{data[:data].count} / #{original_size} rows"
    if !Dir.exists? 'filtered-2'
      Dir.mkdir 'filtered-2'
    end
    write_csv("filtered-2/#{source}-filtered.csv", data)
  end
  
end

main()