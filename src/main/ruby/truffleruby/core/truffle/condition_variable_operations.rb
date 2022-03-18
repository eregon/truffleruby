# frozen_string_literal: true

# Copyright (c) 2021 Oracle and/or its affiliates. All rights reserved. This
# code is released under a tri EPL/GPL/LGPL license. You can use it,
# redistribute it and/or modify it under the terms of the:
#
# Eclipse Public License version 2.0, or
# GNU General Public License version 2, or
# GNU Lesser General Public License version 2.1.

module Truffle::ConditionVariableOperations
  def self.wait_non_blocking(condvar, mutex, timeout)
    # Lock the condition lock
    Truffle::FiberOperations.block_until_true(condvar, nil) do
      Primitive.condition_variable_try_lock(condvar)
    end
    begin
      held_count = 0
      while mutex.owned?
        mutex.unlock
        held_count += 1
      end
      # Mark it as there being a waiter.
      Primitive.condition_variable_wait_non_blocking(condvar)
      # Release the condition lock
      Primitive.condition_variable_unlock(condvar)
      begin
        # Await the signal
        Truffle::FiberOperations.block_until_true(Primitive.object_ivar_get(condvar, :signal_blocker), timeout) do
          !Primitive.condition_variable_consume_signal(condvar)
        end
      rescue => e
        Primitive.condition_variable_consume_signal(condvar)
        raise e
      ensure
        # Relock the condition variable...
        lock(condvar)
        Primitive.condition_variable_wait_cancel(condvar)
      end
    ensure
      # Release the condition lock
      blocker = Primitive.blockable_get_and_set_acquire_blocker(condvar, nil)
      Primitive.condition_variable_unlock(condvar)
      Truffle::FiberOperations.unblock(blocker, condvar) if Primitive.fiber_scheduling?
      # Reacquire the mutex lock.
      exception = nil
      while !mutex.owned?
        begin
          mutex.lock
        rescue => e
          exception = e
        end
      end
      raise exception if exception
    end
  end

  def self.lock(condvar)
    if Primitive.fiber_current_fiber_scheduling?
      Truffle::FiberOperations.block_until_true(condvar, nil) do
        Primitive.condition_variable_try_lock(condvar)
      end
    else
      Primitive.condition_variable_lock(condvar)
    end
  end
end
