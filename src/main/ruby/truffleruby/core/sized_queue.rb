# frozen_string_literal: true

# Copyright (c) 2021 Oracle and/or its affiliates. All rights reserved. This
# code is released under a tri EPL/GPL/LGPL license. You can use it,
# redistribute it and/or modify it under the terms of the:
#
# Eclipse Public License version 2.0, or
# GNU General Public License version 2, or
# GNU Lesser General Public License version 2.1.

class SizedQueue

  def initialize(size)
    Primitive.blockable_set_blocker(self, Truffle::FiberOperations::EMPTY_BLOCKER)
    Primitive.sized_queue_initialize(self, size)
  end

  def pop(nonblocking=false)
    if nonblocking
      value = Truffle::SizedQueueOperations.pop_non_blocking(self)
    elsif Primitive.fiber_current_fiber_scheduling?
      value = nil
      Truffle::FiberOperations.block_until_true(self, nil) do
        if !self.empty?
          value = Primitive.sized_queue_pop_non_blocking(self, Truffle::SizedQueueOperations::EMPTY_MARKER)
          value != Truffle::SizedQueueOperations::EMPTY_MARKER
        elsif self.closed?
          value = nil
          true
        else
          false
        end
      end
    else
      value = Primitive.sized_queue_pop_blocking(self)
    end
    blocker = Primitive.blockable_get_and_set_release_blocker(self, Truffle::FiberOperations::EMPTY_BLOCKER)
    Truffle::FiberOperations.unblock(blocker, self) if Primitive.fiber_scheduling?
    value
  end
  alias_method :shift, :pop
  alias_method :deq, :pop

  # TODO We need two separate unblockers for sized queues, one for reading and one for writing.
  def push(value, nonblocking=false)
    if nonblocking
      Truffle::SizedQueueOperations.push_non_blocking(self, value)
    elsif Primitive.fiber_current_fiber_scheduling?
      Truffle::FiberOperations.block_until_true(self, nil) do
        res = Primitive.sized_queue_push_non_blocking(self, value, Truffle::SizedQueueOperations::FULL_MARKER, Truffle::SizedQueueOperations::CLOSED_MARKER)
        raise ThreadError, 'queue closed' if res == Truffle::SizedQueueOperations::CLOSED_MARKER
        self == res
      end
    else
      Primitive.sized_queue_push_blocking(self, value)
    end
    blocker = Primitive.blockable_get_and_set_release_blocker(self, Truffle::FiberOperations::EMPTY_BLOCKER)
    Truffle::FiberOperations.unblock(blocker, self) if Primitive.fiber_scheduling?
    self
  end

  alias_method :<<, :push
  alias_method :enq, :push

  def max=(limit)
    old_limit = self.max
    Primitive.sized_queue_set_max(self, limit)
    if limit > old_limit
      blocker = Primitive.blockable_get_and_set_release_blocker(self, Truffle::FiberOperations::EMPTY_BLOCKER)
      Truffle::FiberOperations.unblock(blocker, self) if Primitive.fiber_scheduling?
    end
    limit
  end

  def close
    Primitive.sized_queue_close(self)
    blocker = Primitive.blockable_get_and_set_release_blocker(self, nil)
    Truffle::FiberOperations.unblock(blocker, self) if Primitive.fiber_scheduling?
    self
  end
end
