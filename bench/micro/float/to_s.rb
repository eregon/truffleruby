r = Random.new

ary = Array.new(10000) { r.rand }

benchmark 'float-to-s' do
  ary.map { |x| x.to_s }
end
