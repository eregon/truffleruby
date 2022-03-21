# frozen_string_literal: true

# Copyright (c) 2021 Oracle and/or its affiliates. All rights reserved. This
# code is released under a tri EPL/GPL/LGPL license. You can use it,
# redistribute it and/or modify it under the terms of the:
#
# Eclipse Public License version 2.0, or
# GNU General Public License version 2, or
# GNU Lesser General Public License version 2.1.

module Truffle::QueueOperations

  EMPTY_MARKER = Object.new

  def self.pop_non_blocking(queue)
    value = Primitive.queue_pop_non_blocking(queue, EMPTY_MARKER)
    raise ThreadError, 'queue empty' if value == EMPTY_MARKER
    value
  end
end
