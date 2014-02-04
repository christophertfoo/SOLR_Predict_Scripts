require_relative 'global'
require_relative 'csv'

def load_header_csv(path)
  puts "Loading #{path}..."
  file = File.open(path, "r")
  headers = {}
  while line = read_csv_line(file)
    raise "Number of columns does not match.  Expected: 3, Actual: #{line.count}" if 3 != line.count
    row = {}
    headers[line[0].to_sym] = line[1]
  end
  return(headers)
end

def write_columns(source, data, options={}) 
  options = { :headers => {}, :path => "" }.merge(options)
  headers = options[:headers]
  headers = load_header_csv(path) if options[:headers].empty?
  if !Dir.exists? 'columns'
    Dir.mkdir 'columns'
  end
  f = File.new("columns/#{source}", "w")
  f.write("<table border=\"1\" bordercolor=\"#888\" cellspacing=\"0\" style=\"border-collapse: collapse; border-color: rgb(136, 136, 136); border-width: 1px; text-align: center;\">\n<tbody>\n<tr><th colspan=\"2\" style=\"text-align: center\">#{source}</th></tr>\n<tr><th style=\"text-align: center\">Variable</th><th style=\"text-align: center\">Description</th></tr>\n")
  data[:headers].each do |header|
    f.write("<tr><td>#{header}</td><td>")
    if !headers[header.to_sym].nil?
      f.write("#{headers[header.to_sym]}")
    end
    f.write("</td></tr>\n")
  end
  f.write("</tbody>\n</table>")
  f.close
end

# MAIN
header_join = load_header_csv("headers.csv")
$sources.each do |source|
    data = load_source(source, :load_merged => false)
    write_columns(source, data, :headers => header_join)
end