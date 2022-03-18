r = Random.new

limit = ARGV.pop.to_f

n = ARGV.pop.to_i

ary = Array.new(n) { r.rand((-limit)..(limit))}

ary.each { |x|
  x2 = x.round(5, half: :even)
  dump_x = [x].pack('D').dump
  dump_x2 = [x2].pack('D').dump
  str2 = format("%.5f", x)
  str3 = format("%.5f", x2)
  bits = [x].pack('D').unpack('Q<')[0].to_s(16)
  if str2 != str3
    x2_bits = [x2].pack('D').unpack('Q<')[0].to_s(16)
    printed_bits = [str2.to_f].pack('D').unpack('Q<')[0].to_s(16)
    $stderr.puts "#{x} (#{bits}) rounds to #{str3} (#{x2_bits}) but prints to #{str2} (#{printed_bits})."
  else
    puts "[#{dump_x}, #{dump_x2}]"
  end
}

# puts <<-EOF
# def check(a, b, bits)
#   f = a.unpack('D')[0]
#   str = format("%.5f", f)
#   puts "\#{str} did not equal \#{b} - raw bits \#{bits}" unless str.eql? b
#   f2 = format("%.20f", f).to_f
#   puts "\#{f} did not parse to itself - raw bits \#{bits}" unless f == f2
# end

# ary.each do |args|
#   check(args[0], args[1], args[2])
# end
# EOF
