def fp_to_rational(a)
  a_bits = [a].pack('D').unpack('Q<')[0]
  sign = if (a_bits & 0x8000000000000000) == 0
           1
         else
           -1
         end
  bias_exp = (a_bits & 0x7ff0000000000000) >> 52
  exp = bias_exp - 1023
  if bias_exp == 0 || bias_exp == 0x7ff
    puts "Annoying case"
  else
    mantissa = (a_bits & 0x000fffffffffffff) | 0x0010000000000000
    base = (exp > 0) ? 2 ** exp : Rational(1, 2 ** exp)
    frac = 0
    part = Rational(1, 1)
    while (mantissa != 0)
      frac += 1 * part if (mantissa & 0x0010000000000000) != 0
      part = part / 2
      mantissa = (mantissa << 1) & 0x001fffffffffffff
    end
    frac * base * sign
  end
end

def check_rational(a, b)
  n = fp_to_rational(a)
  int_part = n.to_i
  sign = n < 0 ? -1 : 1
  s = 100000
  f = ((sign * n) % 1) * s
  fint = f.to_i
  d = f % 1
  if d > Rational(1, 2)
    fint += 1
  elsif (d > Rational(1, 2))
    fint += fint % 2
  end

  rounded = int_part + Rational(sign * fint, s)

  puts "#{a} rounded to #{rounded.to_f} instead of #{b}." unless rounded.to_f  == b
  rounded.to_f  == b
end

def check(a, b)
  f = a.unpack('D')[0]
  f2 = b.unpack('D')[0]
  check_rational(f, f2)
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
