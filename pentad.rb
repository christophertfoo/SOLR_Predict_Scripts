def generate_pentads()
  pentads = {}
  temp = Time.new(2014, 1, 1)
  end_time = Time.new(2014, 12, 31)
  count = 1
  while temp != end_time
    temp += 24 * 60 * 60 if pentads.count > 0
    pentad = {}
    pentad[:start] = {}
    pentad[:start][:MON] = temp.month
    pentad[:start][:DAY] = temp.day
    temp += 4 * 24 * 60 * 60
    pentad[:end] = {}
    pentad[:end][:MON] = temp.month
    pentad[:end][:DAY] = temp.day
    pentads[pentad] = count
    count += 1
  end
  return pentads
end

def find_pentad(time)
  pentad = 0
  month = time[:MON]
  day = time[:DAY]
  case month
  when 1
    if day >= 1 && day <= 5
      pentad = 1
    elsif day >= 6 && day <= 10
      pentad = 2
    elsif day >= 11 && day <= 15
      pentad = 3
    elsif day >= 16 && day <= 20
      pentad = 4
    elsif day >= 21 && day <= 25
      pentad = 5
    elsif day >= 26 && day <= 30
      pentad = 6
    elsif day == 31
      pentad = 7
    end
  when 2
    if day >= 1 && day <= 4
      pentad = 7
    elsif day >= 5 && day <= 9
      pentad = 8
    elsif day >= 10 && day <= 14
      pentad = 9
    elsif day >= 15 && day <= 19
      pentad = 10
    elsif day >= 20 && day <= 24
      pentad = 11
    elsif day >= 25 && day <= 28
      pentad = 12
    end
  when 3
    if day == 1
      pentad = 12
    elsif day >= 2 && day <= 6
      pentad = 13
    elsif day >= 7 && day <= 11
      pentad = 14
    elsif day >= 12 && day <= 16
      pentad = 15
    elsif day >= 17 && day <= 21
      pentad = 16
    elsif day >= 22 && day <= 26
      pentad = 17
    elsif day >= 27 && day <= 31
      pentad = 18
    end
  when 4
    if day >= 1 && day <= 5
      pentad = 19
    elsif day >= 6 && day <= 10
      pentad = 20
    elsif day >= 11 && day <= 15
      pentad = 21
    elsif day >= 16 && day <= 20
      pentad = 22
    elsif day >= 21 && day <= 25
      pentad = 23
    elsif day >= 26 && day <= 30
      pentad = 24
    end
  when 5
    if day >= 1 && day <= 5
      pentad = 25
    elsif day >= 6 && day <= 10
      pentad = 26
    elsif day >= 11 && day <= 15
      pentad = 27
    elsif day >= 16 && day <= 20
      pentad = 28
    elsif day >= 21 && day <= 25
      pentad = 29
    elsif day >= 26 && day <= 30
      pentad = 30
    elsif day == 31
      pentad = 31
    end
  when 6
    if day >= 1 && day <= 4
      pentad = 31
    elsif day >= 5 && day <= 9
      pentad = 32
    elsif day >= 10 && day <= 14
      pentad = 33
    elsif day >= 15 && day <= 19
      pentad = 34
    elsif day >= 20 && day <= 24
      pentad = 35
    elsif day >= 25 && day <= 29
      pentad = 36
    elsif day == 30
      pentad = 37
    end
  when 7
    if day >= 1 && day <= 4
      pentad = 37
    elsif day >= 5 && day <= 9
      pentad = 38
    elsif day >= 10 && day <= 14
      pentad = 39
    elsif day >= 15 && day <= 19
      pentad = 40
    elsif day >= 20 && day <= 24
      pentad = 41
    elsif day >= 25 && day <= 29
      pentad = 42
    elsif day >= 30 && day <= 31
      pentad = 43
    end
  when 8
    if day >= 1 && day <= 3
      pentad = 43
    elsif day >= 4 && day <= 8
      pentad = 44
    elsif day >= 9 && day <= 13
      pentad = 45
    elsif day >= 14 && day <= 18
      pentad = 46
    elsif day >= 19 && day <= 23
      pentad = 47
    elsif day >= 24 && day <= 28
      pentad = 48
    elsif day >= 29 && day <= 31
      pentad = 49
    end
  when 9
    if day >= 1 && day <= 2
      pentad = 49
    elsif day >= 3 && day <= 7
      pentad = 50
    elsif day >= 8 && day <= 12
      pentad = 51
    elsif day >= 13 && day <= 17
      pentad = 52
    elsif day >= 18 && day <= 22
      pentad = 53
    elsif day >= 23 && day <= 27
      pentad = 54
    elsif day >= 28 && day <= 30
      pentad = 55
    end
  when 10
    if day >= 1 && day <= 2
      pentad = 55
    elsif day >= 3 && day <= 7
      pentad = 56
    elsif day >= 8 && day <= 12
      pentad = 57
    elsif day >= 13 && day <= 17
      pentad = 58
    elsif day >= 18 && day <= 22
      pentad = 59
    elsif day >= 23 && day <= 27
      pentad = 60
    elsif day >= 28 && day <= 31
      pentad = 61
    end
  when 11
    if day == 1
      pentad = 61
    elsif day >= 2 && day <= 6
      pentad = 62
    elsif day >= 7 && day <= 11
      pentad = 63
    elsif day >= 12 && day <= 16
      pentad = 64
    elsif day >= 17 && day <= 21
      pentad = 65
    elsif day >= 22 && day <= 26
      pentad = 66
    elsif day >= 27 && day <= 30
      pentad = 67
    end
  when 12
    if day == 1
      pentad = 67
    elsif day >= 2 && day <= 6
      pentad = 68
    elsif day >= 7 && day <= 11
      pentad = 69
    elsif day >= 12 && day <= 16
      pentad = 70
    elsif day >= 17 && day <= 21
      pentad = 71
    elsif day >= 22 && day <= 26
      pentad = 72
    elsif day >= 27 && day <= 31
      pentad = 73
    end
  end
  return pentad
end

def set_pentads(data)
  num_rows = data[:data].count
  for i in 0...num_rows
    data[:data][i][:PENTAD] = find_pentad(:MON => data[:data][i][:MON].to_i, :DAY => data[:data][i][:DAY].to_i).to_s 
  end
  data[:headers].push("PENTAD")
  return data
end