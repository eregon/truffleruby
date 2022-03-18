require_relative '../../spec_helper'
require_relative "fixtures/classes"

ruby_version_is "3.0" do
  describe "A fiber scheduler" do
    it "raises a ThreadError if a dead fiber is resumed by the scheduler" do
      mutex = Mutex.new
      scheduler = Class.new(FiberSpecs::BlockUnblockScheduler) do
        def resume_execution(fiber)
          fiber.resume
          fiber.resume
        end
      end.new
      -> {Thread.new do
            Fiber.set_scheduler scheduler

            mutex.lock
            Fiber.schedule do
              begin
                mutex.lock
                mutex.unlock
              end
            end
            mutex.unlock
          end.join }.should raise_error(FiberError)
    end

    ruby_bug "", ""..."3.1" do
      it "errors raised in unblock are raised as normal" do
        mutex = Mutex.new
        scheduler = Class.new(FiberSpecs::EmptyScheduler) do
          def unblock(blocker, fiber)
            raise RuntimeError, "Evil"
          end
        end.new
        -> {Thread.new do
              Fiber.set_scheduler scheduler

              mutex.lock
              Fiber.schedule do
                begin
                  mutex.lock
                  mutex.unlock
                end
              end
              Fiber.schedule do
                begin
                  mutex.lock
                  mutex.unlock
                end
              end
              mutex.unlock
            end.join }.should raise_error(RuntimeError, "Evil")
      end
    end
  end
end
