r = Random.new

limit = ARGV.pop.to_f

n = ARGV.pop.to_i

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
    base = Rational(2, 1) ** exp
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

def rational_to_fp(a)
  sign = if (a < 0)
           -1
         else
           1
         end
  abs = a * sign
  base = Rational(1, 1)
  exp = 0
  while (abs > 2 * base)
    base = base * 2
    exp += 1
  end
  while (base > abs)
    base = base / 2
    exp -= 1
  end
  bias_exp = exp + 1023
  mantissa = 0
  abs -= base
  # Count out our 52 bits of precision.

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
  elsif (d >= Rational(1, 2))
    fint += fint % 2
  end

  rounded = int_part + Rational(sign * fint, s)

  puts "#{a} rounded to #{rounded.to_f} instead of #{b}." unless rounded.to_f  == b
  rounded.to_f  == b
end

n.times do
  x = r.rand((-limit)..(limit))
  check_rational(x, x.round(5))
end
