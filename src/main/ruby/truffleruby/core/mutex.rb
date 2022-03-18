# frozen_string_literal: true

# Copyright (c) 2007-2015, Evan Phoenix and contributors
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of Rubinius nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

class Mutex
  def marshal_dump
    raise TypeError, "can't dump #{self.class}"
  end

  def lock
    if Primitive.fiber_current_fiber_scheduling?
      Truffle::FiberOperations.block_until_true(self, nil) do
        Primitive.mutex_try_lock(Primitive.mutex_check_not_held(self))
      end
    else
      Primitive.mutex_lock(self)
    end
    Primitive.blockable_set_release_blocker(self, Truffle::FiberOperations::EMPTY_BLOCKER)
    self
  end

  def try_lock
    if owned?
      false
    else
      if Primitive.mutex_try_lock(self)
        Primitive.blockable_set_release_blocker(self, Truffle::FiberOperations::EMPTY_BLOCKER)
        true
      else
        false
      end
    end
  end

  def unlock
    blocker = Primitive.blockable_get_and_set_acquire_blocker(self, nil)
    Primitive.mutex_unlock(self)
    Truffle::FiberOperations.unblock(blocker, self) if Primitive.fiber_scheduling?
    self
  end

  def synchronize(&block)
    lock
    begin
      yield
    ensure
      unlock
    end
  end

  def sleep(duration=nil)
    interval = Primitive.time_duration_to_nano(duration || undefined)
    Truffle::MutexOperations.ownership_error(self) unless owned?
    begin
      unlock
      scheduler = Primitive.fiber_scheduler_if_needed
      if scheduler
        scheduler.kernel_sleep(duration)
      else
        Primitive.kernel_sleep(interval)
      end
    ensure
      lock
    end
  end
end
