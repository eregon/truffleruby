# frozen_string_literal: true

# Copyright (c) 2021 Oracle and/or its affiliates. All rights reserved. This
# code is released under a tri EPL/GPL/LGPL license. You can use it,
# redistribute it and/or modify it under the terms of the:
#
# Eclipse Public License version 2.0, or
# GNU General Public License version 2, or
# GNU Lesser General Public License version 2.1.

class Fiber
  def initialize(blocking: false, **args, &block)
    Primitive.fiber_initialize(self, Primitive.as_boolean(blocking), block)
  end

  def raise(*args)
    exc = Truffle::ExceptionOperations.make_exception(args)
    exc = RuntimeError.new('') unless exc
    Primitive.fiber_raise(self, exc)
  end

  def inspect
    loc = Primitive.fiber_source_location(self)
    status = Primitive.fiber_status(self)
    "#{super.delete_suffix('>')} #{loc} (#{status})>"
  end
  alias_method :to_s, :inspect

  def self.scheduler
    Primitive.thread_get_scheduler(Thread.current)
  end

  def self.set_scheduler(scheduler)
    current_scheduler = Primitive.thread_get_scheduler(Thread.current)
    current_scheduler.close if current_scheduler && current_scheduler.respond_to?(:close)
    Primitive.thread_set_scheduler(Thread.current, scheduler)
  end

  def self.schedule(&block)
    raise RuntimeError, 'No scheduler is available!' unless scheduler
    scheduler.fiber(&block)
  end

  def self.yield(*args)
    return Primitive.fiber_yield(args) unless Primitive.fiber_scheduling?
    proc = Primitive.fiber_get_block_proc
    blocker = proc ? proc.call(Primitive.fiber_current) : nil
    Primitive.blockable_set_blocker(Primitive.fiber_current, blocker) if blocker
    value = Primitive.fiber_yield(args)
    if blocker
      while !Primitive.blockable_compare_and_set_blocker(Primitive.fiber_current, blocker, nil) do
      end
    end
    value
  end
end
