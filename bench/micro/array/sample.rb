# Copyright (c) 2020 Oracle and/or its affiliates. All rights reserved. This
# code is released under a tri EPL/GPL/LGPL license. You can use it,
# redistribute it and/or modify it under the terms of the:
#
# Eclipse Public License version 2.0, or
# GNU General Public License version 2, or
# GNU Lesser General Public License version 2.1.

CHI_SQUARED_CRITICAL_VALUES = [
  0,
  6.635, 9.210, 11.345, 13.277, 15.086, 16.812, 18.475, 20.090, 21.666, 23.209,
  24.725, 26.217, 27.688, 29.141, 30.578, 32.000, 33.409, 34.805, 36.191, 37.566,
  38.932, 40.289, 41.638, 42.980, 44.314, 45.642, 46.963, 48.278, 49.588, 50.892,
  52.191, 53.486, 54.776, 56.061, 57.342, 58.619, 59.893, 61.162, 62.428, 63.691,
  64.950, 66.206, 67.459, 68.710, 69.957, 71.201, 72.443, 73.683, 74.919, 76.154,
  77.386, 78.616, 79.843, 81.069, 82.292, 83.513, 84.733, 85.950, 87.166, 88.379,
  89.591, 90.802, 92.010, 93.217, 94.422, 95.626, 96.828, 98.028, 99.228, 100.425,
  101.621, 102.816, 104.010, 105.202, 106.393, 107.583, 108.771, 109.958, 111.144, 112.329,
  113.512, 114.695, 115.876, 117.057, 118.236, 119.414, 120.591, 121.767, 122.942, 124.116,
  125.289, 126.462, 127.633, 128.803, 129.973, 131.141, 132.309, 133.476, 134.642, 135.807,
]

def self.measure_sample_fairness(size, samples, iters)
  ary = Array.new(size) { |x| x }
  (samples).times do |i|
    chi_results = []
    3.times do
      counts = Array.new(size) { 0 }
      expected = iters / size
      iters.times do
        x = ary.sample(samples)[i]
        counts[x] += 1
      end
      chi_squared = 0.0
      counts.each do |count|
        chi_squared += (((count - expected) ** 2) * 1.0 / expected)
      end
      chi_results << chi_squared
      break if chi_squared <= CHI_SQUARED_CRITICAL_VALUES[size]
    end

    chi_results.min
  end
end

def self.measure_sample_fairness_large_sample_size(size, samples, iters)
  ary = Array.new(size) { |x| x }
  counts = Array.new(size) { 0 }
  expected = iters * samples / size
  iters.times do
    ary.sample(samples).each do |sample|
      counts[sample] += 1
    end
  end
  chi_squared = 0.0
  counts.each do |count|
    chi_squared += (((count - expected) ** 2) * 1.0 / expected)
  end

  # Chi squared critical values for tests with 4 degrees of freedom
  # Values obtained from NIST Engineering Statistic Handbook at
  # https://www.itl.nist.gov/div898/handbook/eda/section3/eda3674.htm

  chi_squared
end

benchmark do
  measure_sample_fairness(4, 1, 4000)
end

benchmark do
  measure_sample_fairness(4, 2, 4000)
end

benchmark do
  measure_sample_fairness(4, 3, 4000)
end

benchmark do
  measure_sample_fairness(40, 3, 4000)
end

benchmark do
  measure_sample_fairness(40, 4, 4000)
end

benchmark do
  measure_sample_fairness(40, 8, 4000)
end

benchmark do
  measure_sample_fairness(40, 16, 4000)
end

benchmark do
  measure_sample_fairness_large_sample_size(100, 80, 40000)
end
