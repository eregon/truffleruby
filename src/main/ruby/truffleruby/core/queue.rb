# frozen_string_literal: true

# Copyright (c) 2021 Oracle and/or its affiliates. All rights reserved. This
# code is released under a tri EPL/GPL/LGPL license. You can use it,
# redistribute it and/or modify it under the terms of the:
#
# Eclipse Public License version 2.0, or
# GNU General Public License version 2, or
# GNU Lesser General Public License version 2.1.

class Queue

  def initialize
    Primitive.blockable_set_blocker(self, Truffle::FiberOperations::EMPTY_BLOCKER)
  end

  def pop(nonblocking=false)
    if nonblocking
      Truffle::QueueOperations.pop_non_blocking(self)
    elsif Primitive.fiber_current_fiber_scheduling?
      value = nil
      Truffle::FiberOperations.block_until_true(self, nil) do
        if !self.empty?
          value = Primitive.queue_pop_non_blocking(self, Truffle::QueueOperations::EMPTY_MARKER)
          value != Truffle::QueueOperations::EMPTY_MARKER
        elsif self.closed?
          value = nil
          true
        else
          false
        end
      end
      value
    else
      Primitive.queue_pop_blocking(self)
    end
  end
  alias_method :shift, :pop
  alias_method :deq, :pop

  def push(value)
    blocker = Primitive.blockable_get_and_set_acquire_blocker(self, Truffle::FiberOperations::EMPTY_BLOCKER)
    Primitive.queue_push(self, value)
    Truffle::FiberOperations.unblock(blocker, self) if Primitive.fiber_scheduling?
    self
  end

  alias_method :<<, :push
  alias_method :enq, :push

  def close
    Primitive.queue_close(self)
    blocker = Primitive.blockable_get_and_set_release_blocker(self, nil)
    Truffle::FiberOperations.unblock(blocker, self) if Primitive.fiber_scheduling?
    self
  end
end
