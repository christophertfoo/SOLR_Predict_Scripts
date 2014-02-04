require 'nokogiri'
require 'open-uri'

def main
  stations = %w[KKRH1 MKRH1 D5064 MKHH1 WNVH1 D3665 51201 SCSH1 PLHH1 SCBH1 51204 HOUH1 PHJR PHHI HOFH1 KMRH1 PPRH1 SCEH1 WWFH1 PHNL KTAH1 KFWH1 PMHH1 OFRH1 NHSH1 KNRH1 OOUH1 WHSH1 MOGH1 51207 MOKH1 C0875 PHNG C9190 AS839 E3625]
  years = 1997..2013
  puts "Getting data from #{stations.count} stations"
  stations.each do |station|
    puts "Getting data from #{station}..."
    variables = get_variables(station)
    years.each do |year|
      puts "  #{year}..."
      data = get_data(station, year, variables)
      if data.count("\n") >= 1
        if !Dir.exists? station
          Dir.mkdir station
        end
        puts "    Writing to #{station}/#{station}-#{year}.csv"
        f = File.new("#{station}/#{station}-#{year}.csv", 'w')
        f.write(data)
        f.close
      else
        puts "    There is no data"
      end
    end
  end
end

def get_variables(station)
  doc = Nokogiri::HTML(open("http://mesowest.utah.edu/cgi-bin/droman/download_ndb.cgi?stn=#{station}"))
  variables = []
  doc.css("input[type=checkbox]").each do |box|
    variables.push(box.attr(:value))
  end
  return variables
end

def get_data(station, year, variables=[])
  if variables.count < 1
    variables = get_variables(station)
  end
  url = "http://mesowest.utah.edu/cgi-bin/droman/meso_download_mesowest_ndb.cgi?product=&stn=#{station}&unit=0&time=LOCAL&daycalendar=0&yearcal=#{year}&monthcal=13&hours=1&output=csv&order=0"
  variables.each do |var|
    url += "&#{var}=#{var}"
  end
  doc = Nokogiri::HTML(open(url))
  data = doc.css("pre").text
  data[data.index("PARM = ") + 7..-1].strip.sub(/\n\n/, "\n")
end

main()