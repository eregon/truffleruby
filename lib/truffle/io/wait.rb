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
    Truffle::IOOperations.wait(self, IO::READABLE, timeout)
  end

  def wait(*args)
    if args.size != 2 || Primitive.object_kind_of?(args[0], Symbol) || Primitive.object_kind_of?(args[1], Symbol)
      timeout = :undef
      events = 0
      args.each do |arg|
        if Primitive.object_kind_of?(arg, Symbol)
          events |= Truffle::IOOperations.wait_event_mask([arg])
        elsif timeout == :undef
          timeout = arg
        else
          raise ArgumentError, 'timeout given more than once'
        end
      end

      if timeout == :undef
        timeout = nil
      end
    else
      events = args[0]
      timeout = args[1]
    end

    events = IO::READABLE if events == 0

    if @ibuffer && events & IO::READABLE != 0
      return true if @ibuffer.size > 0
    end

    Truffle::IOOperations.wait(self, events, timeout)
  end

  def wait_writable(timeout = nil)
    Truffle::IOOperations.wait(self, IO::WRITABLE, timeout)
  end
end
