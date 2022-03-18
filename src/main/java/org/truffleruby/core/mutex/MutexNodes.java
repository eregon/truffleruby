/*
 * Copyright (c) 2015, 2021 Oracle and/or its affiliates. All rights reserved. This
 * code is released under a tri EPL/GPL/LGPL license. You can use it,
 * redistribute it and/or modify it under the terms of the:
 *
 * Eclipse Public License version 2.0, or
 * GNU General Public License version 2, or
 * GNU Lesser General Public License version 2.1.
 */
package org.truffleruby.core.mutex;

import com.oracle.truffle.api.dsl.Cached;
import com.oracle.truffle.api.dsl.Specialization;
import com.oracle.truffle.api.profiles.BranchProfile;
import com.oracle.truffle.api.profiles.ConditionProfile;
import org.truffleruby.builtins.CoreMethod;
import org.truffleruby.builtins.CoreMethodArrayArgumentsNode;
import org.truffleruby.builtins.CoreModule;
import org.truffleruby.builtins.Primitive;
import org.truffleruby.builtins.PrimitiveArrayArgumentsNode;
import org.truffleruby.builtins.UnaryCoreMethodNode;
import org.truffleruby.core.klass.RubyClass;
import org.truffleruby.core.thread.RubyThread;
import org.truffleruby.language.Visibility;
import org.truffleruby.language.control.RaiseException;
import org.truffleruby.language.objects.AllocationTracing;

import java.util.concurrent.locks.ReentrantLock;

@CoreModule(value = "Mutex", isClass = true)
public abstract class MutexNodes {

    @CoreMethod(names = { "__allocate__", "__layout_allocate__" }, constructor = true, visibility = Visibility.PRIVATE)
    public abstract static class AllocateNode extends CoreMethodArrayArgumentsNode {

        @Specialization
        protected RubyMutex allocate(RubyClass rubyClass) {
            final ReentrantLock lock = MutexOperations.newReentrantLock();
            final RubyMutex instance = new RubyMutex(rubyClass, getLanguage().mutexShape, lock);
            AllocationTracing.trace(instance, this);
            return instance;
        }
    }

    @Primitive(name = "mutex_lock")
    public abstract static class LockNode extends PrimitiveArrayArgumentsNode {

        @Specialization
        protected RubyMutex lock(RubyMutex mutex,
                @Cached BranchProfile errorProfile) {
            final ReentrantLock lock = mutex.lock;

            if (lock.isHeldByCurrentThread()) {
                errorProfile.enter();
                throw new RaiseException(getContext(), coreExceptions().threadErrorRecursiveLocking(this));
            }

            final RubyThread thread = getLanguage().getCurrentThread();
            MutexOperations.lock(getContext(), lock, thread, this);
            return mutex;
        }

    }

    @Primitive(name = "mutex_check_not_held")
    public abstract static class CheckNotHeldNode extends PrimitiveArrayArgumentsNode {

        @Specialization
        protected Object checkNotHeld(RubyMutex mutex,
                @Cached BranchProfile errorProfile) {
            final ReentrantLock lock = mutex.lock;

            if (lock.isHeldByCurrentThread()) {
                errorProfile.enter();
                throw new RaiseException(getContext(), coreExceptions().threadErrorRecursiveLocking(this));
            }
            return mutex;
        }
    }

    @CoreMethod(names = "locked?")
    public abstract static class IsLockedNode extends UnaryCoreMethodNode {

        @Specialization
        protected boolean isLocked(RubyMutex mutex) {
            return mutex.lock.isLocked();
        }

    }

    @CoreMethod(names = "owned?")
    public abstract static class IsOwnedNode extends UnaryCoreMethodNode {
        @Specialization
        protected boolean isOwned(RubyMutex mutex) {
            return mutex.lock.isHeldByCurrentThread();
        }
    }

    @Primitive(name = "mutex_try_lock")
    public abstract static class TryLockNode extends PrimitiveArrayArgumentsNode {

        @Specialization
        protected boolean tryLock(RubyMutex mutex,
                @Cached ConditionProfile heldByCurrentThreadProfile) {
            final ReentrantLock lock = mutex.lock;
            return MutexOperations.tryLock(lock, getLanguage().getCurrentThread());
        }
    }

    @Primitive(name = "mutex_unlock")
    public abstract static class UnlockNode extends PrimitiveArrayArgumentsNode {

        @Specialization
        protected RubyMutex unlock(RubyMutex mutex,
                @Cached BranchProfile errorProfile) {
            final ReentrantLock lock = mutex.lock;
            final RubyThread thread = getLanguage().getCurrentThread();

            MutexOperations.checkOwnedMutex(getContext(), lock, this, errorProfile);
            MutexOperations.unlock(lock, thread);
            return mutex;
        }

    }
}
