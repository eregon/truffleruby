/*
 * Copyright (c) 2015, 2021 Oracle and/or its affiliates. All rights reserved. This
 * code is released under a tri EPL/GPL/LGPL license. You can use it,
 * redistribute it and/or modify it under the terms of the:
 *
 * Eclipse Public License version 2.0, or
 * GNU General Public License version 2, or
 * GNU Lesser General Public License version 2.1.
 */
package org.truffleruby.core.queue;

import com.oracle.truffle.api.CompilerDirectives.TruffleBoundary;
import com.oracle.truffle.api.dsl.Cached;
import com.oracle.truffle.api.dsl.Specialization;
import com.oracle.truffle.api.profiles.BranchProfile;
import org.truffleruby.builtins.CoreMethod;
import org.truffleruby.builtins.CoreMethodArrayArgumentsNode;
import org.truffleruby.builtins.CoreModule;
import org.truffleruby.builtins.Primitive;
import org.truffleruby.builtins.PrimitiveArrayArgumentsNode;
import org.truffleruby.core.klass.RubyClass;
import org.truffleruby.core.thread.ThreadManager.BlockingAction;
import org.truffleruby.language.Visibility;
import org.truffleruby.language.control.RaiseException;
import org.truffleruby.language.objects.AllocationTracing;
import org.truffleruby.language.objects.shared.PropagateSharingNode;

/** We do not reuse much of class Queue since we need to be able to replace the queue in this case and methods are small
 * anyway. */
@CoreModule(value = "SizedQueue", isClass = true)
public abstract class SizedQueueNodes {

    @CoreMethod(names = { "__allocate__", "__layout_allocate__" }, constructor = true, visibility = Visibility.PRIVATE)
    public abstract static class AllocateNode extends CoreMethodArrayArgumentsNode {

        @Specialization
        protected RubySizedQueue allocate(RubyClass rubyClass) {
            final RubySizedQueue instance = new RubySizedQueue(rubyClass, getLanguage().sizedQueueShape, null);
            AllocationTracing.trace(instance, this);
            return instance;
        }

    }

    @Primitive(name = "sized_queue_initialize", lowerFixnum = 1)
    public abstract static class InitializeNode extends PrimitiveArrayArgumentsNode {

        @Specialization
        protected RubySizedQueue initialize(RubySizedQueue self, int capacity,
                @Cached BranchProfile errorProfile) {
            if (capacity <= 0) {
                errorProfile.enter();
                throw new RaiseException(
                        getContext(),
                        coreExceptions().argumentError("queue size must be positive", this));
            }

            final SizedQueue blockingQueue = new SizedQueue(capacity);
            self.queue = blockingQueue;
            return self;
        }

    }

    @Primitive(name = "sized_queue_set_max", lowerFixnum = 1)
    public abstract static class SetMaxNode extends CoreMethodArrayArgumentsNode {

        @Specialization
        protected int setMax(RubySizedQueue self, int newCapacity,
                @Cached BranchProfile errorProfile) {
            if (newCapacity <= 0) {
                errorProfile.enter();
                throw new RaiseException(
                        getContext(),
                        coreExceptions().argumentError("queue size must be positive", this));
            }

            final SizedQueue queue = self.queue;
            queue.changeCapacity(newCapacity);
            return newCapacity;
        }

    }

    @CoreMethod(names = "max")
    public abstract static class MaxNode extends CoreMethodArrayArgumentsNode {

        @Specialization
        protected int max(RubySizedQueue self) {
            final SizedQueue queue = self.queue;
            return queue.getCapacity();
        }

    }

    @Primitive(name = "sized_queue_push_blocking")
    public abstract static class PushblockingNode extends PrimitiveArrayArgumentsNode {

        @Child PropagateSharingNode propagateSharingNode = PropagateSharingNode.create();

        @Specialization
        protected RubySizedQueue pushBlocking(RubySizedQueue self, final Object value) {
            final SizedQueue queue = self.queue;

            propagateSharingNode.executePropagate(self, value);
            doPushBlocking(value, queue);

            return self;
        }

        @TruffleBoundary
        private void doPushBlocking(final Object value, final SizedQueue queue) {
            getContext().getThreadManager().runUntilResult(this, () -> {
                if (queue.put(value)) {
                    return BlockingAction.SUCCESS;
                } else {
                    throw new RaiseException(getContext(), coreExceptions().closedQueueError(this));
                }
            });
        }
    }

    @Primitive(name = "sized_queue_push_non_blocking")
    public abstract static class PushNonBlockingNode extends PrimitiveArrayArgumentsNode {

        @Child PropagateSharingNode propagateSharingNode = PropagateSharingNode.create();

        @Specialization
        protected Object pushNonBlock(RubySizedQueue self, final Object value, Object fullMarker, Object closedMarker,
                @Cached BranchProfile errorProfile) {
            final SizedQueue queue = self.queue;

            propagateSharingNode.executePropagate(self, value);

            switch (queue.offer(value)) {
                case SUCCESS:
                    return self;
                case FULL:
                    errorProfile.enter();
                    return fullMarker;
                case CLOSED:
                    errorProfile.enter();
                    return closedMarker;
            }

            return self;
        }

    }

    @Primitive(name = "sized_queue_pop_blocking")
    public abstract static class PopBlockNode extends PrimitiveArrayArgumentsNode {

        @Specialization
        protected Object getNonBlocking(RubySizedQueue rubyQueue,
                @Cached BranchProfile closedProfile) {
            final SizedQueue queue = rubyQueue.queue;

            final Object value = doPop(queue);

            if (value == SizedQueue.CLOSED) {
                closedProfile.enter();
                return nil;
            } else {
                return value;
            }
        }

        @TruffleBoundary
        private Object doPop(SizedQueue queue) {
            return getContext().getThreadManager().runUntilResult(this, queue::take);
        }

    }

    @Primitive(name = "sized_queue_pop_non_blocking")
    public abstract static class PopNonBlockNode extends PrimitiveArrayArgumentsNode {

        @Specialization
        protected Object getNonBlocking(RubySizedQueue rubyQueue, Object marker) {
            final SizedQueue queue = rubyQueue.queue;

            final Object value = queue.poll();

            return value == null ? marker : value;
        }

    }

    @CoreMethod(names = "empty?")
    public abstract static class EmptyNode extends CoreMethodArrayArgumentsNode {

        @Specialization
        protected boolean empty(RubySizedQueue self) {
            final SizedQueue queue = self.queue;
            return queue.isEmpty();
        }

    }

    @CoreMethod(names = { "size", "length" })
    public abstract static class SizeNode extends CoreMethodArrayArgumentsNode {

        @Specialization
        protected int size(RubySizedQueue self) {
            final SizedQueue queue = self.queue;
            return queue.size();
        }

    }

    @CoreMethod(names = "clear")
    public abstract static class ClearNode extends CoreMethodArrayArgumentsNode {

        @Specialization
        protected RubySizedQueue clear(RubySizedQueue self) {
            final SizedQueue queue = self.queue;
            queue.clear();
            return self;
        }

    }

    @CoreMethod(names = "num_waiting")
    public abstract static class NumWaitingNode extends CoreMethodArrayArgumentsNode {

        @Specialization
        protected int num_waiting(RubySizedQueue self) {
            final SizedQueue queue = self.queue;
            return queue.getNumberWaiting();
        }

    }

    @Primitive(name = "sized_queue_close")
    public abstract static class CloseNode extends PrimitiveArrayArgumentsNode {

        @Specialization
        protected RubySizedQueue close(RubySizedQueue self) {
            self.queue.close();
            return self;
        }

    }

}
