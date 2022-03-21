# frozen_string_literal: true

# Copyright (c) 2021 Oracle and/or its affiliates. All rights reserved. This
# code is released under a tri EPL/GPL/LGPL license. You can use it,
# redistribute it and/or modify it under the terms of the:
#
# Eclipse Public License version 2.0, or
# GNU General Public License version 2, or
# GNU Lesser General Public License version 2.1.

module Truffle::SizedQueueOperations

  EMPTY_MARKER = Object.new
  FULL_MARKER = Object.new
  CLOSED_MARKER = Object.new

  def self.pop_non_blocking(queue)
    value = Primitive.sized_queue_pop_non_blocking(queue, EMPTY_MARKER)
    raise ThreadError, 'queue empty' if value == EMPTY_MARKER
    value
  end

  def self.push_non_blocking(queue, value)
    value = Primitive.sized_queue_push_non_blocking(queue, value, FULL_MARKER, CLOSED_MARKER)
    raise ThreadError, 'queue full' if value == FULL_MARKER
    raise ThreadError, 'queue closed' if value == CLOSED_MARKER
    value
  end
end
