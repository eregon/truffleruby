# Copyright (c) 2022 Oracle and/or its affiliates. All rights reserved. This
# code is released under a tri EPL/GPL/LGPL license. You can use it,
# redistribute it and/or modify it under the terms of the:
#
# Eclipse Public License version 2.0, or
# GNU General Public License version 2, or
# GNU Lesser General Public License version 2.1.

module Truffle
  module Socket
    module Connect
      def self.wait_connectable(socket)
        errno = socket.getsockopt(::Socket::SOL_SOCKET, ::Socket::SO_ERROR).unpack('i')[0]
        return -1 if errno < 0
        if errno == Errno::EALREADY::Errno ||
           errno == Errno::EISCONN::Errno ||
           errno == Errno::ECONNREFUSED::Errno ||
           errno == Errno::EHOSTUNREACH::Errno
          Errno.errno = errno
          return -1
        end

        return -1 unless Truffle::IOOperations.wait(socket, ::IO::WRITABLE, nil)

        errno = socket.getsockopt(::Socket::SOL_SOCKET, ::Socket::SO_ERROR).unpack('i')[0]
        return -1 if errno < 0

        if errno == 0 ||
           errno == Errno::EINTR::Errno ||
           ((defined? Errno::ERESTART) && errno == Errno::ERESTART::Errno) ||
           errno == Errno::EINPROGRESS::Errno ||
           errno == Errno::EALREADY::Errno ||
           errno == Errno::EISCONN::Errno
          0
        else
          Errno.errno = errno
          -1
        end
      end
    end
  end
end
