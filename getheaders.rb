require 'nokogiri'
require 'open-uri'

def main
  doc = Nokogiri::HTML(open("http://mesowest.utah.edu/cgi-bin/droman/variable_download_select.cgi"))
  table = doc.css("table")[1]
  rows = table.css("tr")
  headers = rows.first.css("td").map{ |td| td.text }
  f = File.new("headers.csv", "w")
  f.write("#{headers[0]},#{headers[1]},Units\n")
  for i in 1...rows.count
    columns = rows[i].css("td").map{ |td| td.text }
    f.write("#{columns[0]},#{columns[1]},#{columns[2]}\n")
  end
  f.close
end

main()