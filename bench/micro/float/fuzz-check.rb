def check(a, b)
  f = a.unpack('D')[0]
  f2 = b.unpack('D')[0]
  rounded = f.round(5, half: :even)
  puts "#{f} rounded to 5 dp #{f2} != #{rounded}" unless f2 == rounded
  return f2 == rounded
end

success = 0
failure = 0

while (line = $stdin.gets)
  ary = eval(line)
  if check(*ary)
    success += 1
  else
    failure += 1
  end
end

puts "Tested #{success + failure} cases, #{failure} failures detected."
