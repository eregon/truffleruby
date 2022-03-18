require 'fiber'
require 'socket'

begin
  require 'io/nonblock'
rescue LoadError
  # Ignore.
end

module FiberSpecs

  class EmptyScheduler

    def io_wait(io, events, duration)
      Fiber.yield
      return true
    end

    def block(blocker, timeout = nil)
      Fiber.yield
    end

    def unblock(blocker, fiber)
    end

    def fiber(&block)
      fiber = Fiber.new(blocking: false, &block)

      fiber.resume

      return fiber
    end
  end

  class NewFiberToRaise
    def self.raise(*args)
      fiber = Fiber.new { Fiber.yield }
      fiber.resume
      fiber.raise(*args)
    end
  end

  class CustomError < StandardError; end
end
