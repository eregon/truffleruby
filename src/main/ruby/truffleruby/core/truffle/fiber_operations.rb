# frozen_string_literal: true

# Copyright (c) 2021 Oracle and/or its affiliates. All rights reserved. This
# code is released under a tri EPL/GPL/LGPL license. You can use it,
# redistribute it and/or modify it under the terms of the:
#
# Eclipse Public License version 2.0, or
# GNU General Public License version 2, or
# GNU Lesser General Public License version 2.1.

module Truffle::FiberOperations

  # Most of these methods are concerned with handling the interactions
  # between fibers and schedulers. Objects which can block should be
  # written to work with the blocker primitives, and use a Blocker to
  # represent their state. An empty blocker is an indication that
  # while nothing is currently blocked on an object it is reasonable
  # to block and wait to be unblocked later, while a nil blocker
  # indicates that the object is not in a state where blockers should
  # wait (for example a lock is in the process of being unlocked) and
  # the waiting thread should spin until either it can continue or the
  # object has entered a state where it can be waited on again.

  EMPTY_BLOCKER = Primitive.blocker_create(nil, nil)

  # This method is the main way to block a fiber with a
  # scheduler. Callers should pass in the object to be blocked on, a
  # time limit (which may be nil) and a block representing the
  # condition that must be true to continue execution (for example the
  # successful acquisition of a lock). The time limit and condition
  # will be checked, and if the time has expired or the condition has
  # been met then execution will continue as normal, otherwise we will
  # attempt to add a new blocker to the object, and block the fiber
  # using the scheduler. If the current blocker is nil then we will
  # continue to check the time limit and condition until either
  # execution can continue or the object enters a state on which it
  # can be waited on again. If a race occurs then block and unblock
  # may be multiple times on a scheduler.

  def self.block_until_true(thing, time_limit)
    current_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    if time_limit
      end_time = current_time + time_limit
    end
    while !yield
      if end_time
        current_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        return if end_time <= current_time
      end
      blocker = Primitive.blockable_get_acquire_blocker(thing)
      if blocker
        Truffle::FiberOperations.block_fiber(thing, time_limit) do
          while (!Primitive.blockable_compare_and_set_blocker(thing, blocker, new_blocker = Primitive.blocker_create(blocker, Fiber.current)))
            blocker = Primitive.blockable_get_acquire_blocker(thing)
            if !blocker
              Fiber.scheduler.unblock(thing, Fiber.current)
              new_blocker = nil
              break
            end
          end
          new_blocker
        end
      end
    end
  end

  # Handle unblocking fibers that are waiting on the owner of the
  # blocker. This method will traverse the linked list of blockers and
  # unblock fibers which still have a scheduler. The current blocker
  # on each fiber is checked and set to nil before calling unblock to
  # ensure that a scheduler which has already (or is in the process
  # of) resuming a fiber itself does not also schedule it via an
  # unblock call. The resuming fiber will itself check for the status
  # of the blocker when it resumes, and spin until this method has
  # restored it from its temporary nil value. This is done to ensure
  # there cannot be a race due to a fiber blocking again while this
  # method is still in the process of unblocking it.

  def self.unblock(blocker, thing)
    while (blocker and !(blocker.empty?))
      fiber = blocker.fiber
      if fiber
        if Primitive.blockable_compare_and_set_blocker(fiber, blocker, nil)
          begin
            scheduler = Primitive.fiber_get_scheduler(fiber)
            if scheduler and !fiber.blocking?
              scheduler.unblock(thing, fiber)
            end
          ensure
            Primitive.blockable_set_release_blocker(fiber, blocker)
          end
        end
      end
      blocker = blocker.successor
    end
  end

  # This method does the low level fiber setup needed to handle
  # yielding from within a scheduler. It should only ever be called by
  # other methods in this module.

  def self.block_fiber(reason, timeout, &proc)
    old_proc = Primitive.fiber_get_and_set_block_proc proc
    begin
      Fiber.scheduler.block(reason, timeout)
    ensure
      Primitive.fiber_get_and_set_block_proc old_proc
    end
  end
end
