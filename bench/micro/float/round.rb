r = Random.new

limit = 1.0

n = 10000

ary = Array.new(n) { r.rand((-limit)..(limit)) }
digits = Array.new(n) { r.rand(8) }

benchmark 'float-round-5-even' do
  sum = 0.0
  n.times { |x| sum += ary[x].round(5, half: :even) }
  sum
end

benchmark 'float-round-0-even' do
  sum = 0.0
  n.times { |x| sum += ary[x].round(0, half: :even) }
end

benchmark 'float-round-varies-even' do
  sum = 0.0
  n.times { |x| sum += ary[x].round(digits[x], half: :even) }
end

benchmark 'float-round-5-up' do
  sum = 0.0
  n.times { |x| sum += ary[x].round(5, half: :up) }
end

benchmark 'float-round-0-up' do
  sum = 0.0
  n.times { |x| sum += ary[x].round(0, half: :up) }
end

benchmark 'float-round-5-down' do
  sum = 0.0
  n.times { |x| sum += ary[x].round(5, half: :down) }
end

benchmark 'float-round-0-down' do
  sum = 0.0
  n.times { |x| sum += ary[x].round(0, half: :down) }
end
