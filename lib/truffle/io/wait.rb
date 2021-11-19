# truffleruby_primitives: true

# Copyright (c) 2017, 2019 Oracle and/or its affiliates. All rights reserved. This
# code is released under a tri EPL/GPL/LGPL license. You can use it,
# redistribute it and/or modify it under the terms of the:
#
# Eclipse Public License version 2.0, or
# GNU General Public License version 2, or
# GNU Lesser General Public License version 2.1.

class IO
  def nread
    # If we're buffered return the remaining buffer size (if > 0)
    if @ibuffer
      len = @ibuffer.size
      return len if len > 0
    end
    Truffle::POSIX.truffleposix_ioctl_fionread(self.fileno)
  end

  def ready?
    ensure_open_and_readable
    Truffle::IOOperations.poll(self, Truffle::IOOperations::POLLIN, 0)
  end

  def wait_readable(timeout = nil)
    if @ibuffer
      return true if @ibuffer.size > 0
    end
    ensure_open_and_readable
    scheduler = Fiber.scheduler
    if scheduler && !Fiber.blocking? && scheduler.respond_to?(:io_wait)
      scheduler.io_wait(self, IO::READABLE, timeout)
    else
      Truffle::IOOperations.poll(self, Truffle::IOOperations::POLLIN, timeout) ? self : nil
    end
  end

  def wait(timeout = nil, *args)
    events = Truffle::IOOperations.wait_event_mask(args)
    return wait_readable(timeout) if events == IO::READABLE

    scheduler = Fiber.scheduler
    if scheduler && !Fiber.blocking? && scheduler.respond_to?(:io_wait)
      scheduler.io_wait(self, events, timeout)
    else
      reads = if events & IO::READABLE != 0
                [self]
              else
                []
              end
      writes = if events & IO::WRITABLE != 0
                 [self]
               else
                 []
               end
      Primitive.nil?(Kernel.select(reads, writes, [], timeout)) ? nil : self
    end

  end

  def wait_writable(timeout = nil)
    ensure_open_and_writable
    scheduler = Fiber.scheduler
    if scheduler && !Fiber.blocking? && scheduler.respond_to?(:io_wait)
      scheduler.io_wait(self, IO::WRITABLE, timeout)
    else
      Truffle::IOOperations.poll(self, Truffle::IOOperations::POLLOUT, timeout) ? self : nil
    end
  end
end
