r = Random.new

limit = 1.0

n = 10000

ary = Array.new(n) { r.rand((-limit)..(limit)) }
digits = Array.new(n) { r.rand(8) }

benchmark 'format-float-.5f' do
  ary.map { |x| format("%.5f", x)}
end

benchmark 'format-float-.17f' do
  ary.map { |x| format("%.17f", x)}
end

benchmark 'format-float-.5e' do
  ary.map { |x| format("%.5e", x)}
end

benchmark 'format-float-.17e' do
  ary.map { |x| format("%.17e", x)}
end

benchmark 'format-float-.5g' do
  ary.map { |x| format("%.5g", x)}
end

benchmark 'format-float-.17g' do
  ary.map { |x| format("%.17g", x)}
end

benchmark 'format-float-.5a' do
  ary.map { |x| format("%.5a", x)}
end

benchmark 'format-float-.17a' do
  ary.map { |x| format("%.17a", x)}
end
