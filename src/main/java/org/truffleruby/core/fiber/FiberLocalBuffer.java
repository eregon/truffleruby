/*
 * Copyright (c) 2020, 2021 Oracle and/or its affiliates. All rights reserved. This
 * code is released under a tri EPL/GPL/LGPL license. You can use it,
 * redistribute it and/or modify it under the terms of the:
 *
 * Eclipse Public License version 2.0, or
 * GNU General Public License version 2, or
 * GNU Lesser General Public License version 2.1.
 */
package org.truffleruby.core.fiber;

import com.oracle.truffle.api.profiles.ConditionProfile;

import org.truffleruby.RubyLanguage;
import org.truffleruby.extra.ffi.Pointer;

public final class FiberLocalBuffer {

    public static final FiberLocalBuffer NULL_BUFFER = new FiberLocalBuffer(new Pointer(0, 0), null);
    private static final long ALIGNMENT = 8L;
    private static final long ALIGNMENT_MASK = ALIGNMENT - 1;

    public final Pointer start;
    long remaining;
    private final FiberLocalBuffer parent;

    private FiberLocalBuffer(Pointer start, FiberLocalBuffer parent) {
        this.start = start;
        this.remaining = start.getSize();
        this.parent = parent;
    }

    private boolean invariants() {
        assert remaining >= 0 && remaining <= start.getSize();
        return true;
    }

    private boolean isEmpty() {
        return remaining == start.getSize();
    }

    private long cursor() {
        return start.getEndAddress() - remaining;
    }

    private void freeMemory(RubyLanguage language) {
        remaining = 0;
        if (!start.isNull()) {
            language.releaseBuffer(start);
        }
    }

    public void free(RubyLanguage language, RubyFiber fiber, Pointer ptr, ConditionProfile freeProfile) {
        long size = alignUp(ptr.getSize());
        assert ptr.getAddress() + size == cursor() : "free(" + Long.toHexString(ptr.getAddress()) +
                ", length " + Long.toHexString(size) +
                ") but expected " + Long.toHexString(cursor()) + " to be free'd first";
        remaining += size;
        assert invariants();
        if (isEmpty() && parent != null) {
            fiber.ioBuffer = parent;
            freeMemory(language);
        }
    }

    public void freeAll(RubyLanguage language, RubyFiber fiber) {
        FiberLocalBuffer current = this;
        fiber.ioBuffer = NULL_BUFFER;
        while (current != null) {
            current.freeMemory(language);
            current = current.parent;
        }
    }

    public Pointer allocate(RubyLanguage language, RubyFiber fiber, long size, ConditionProfile allocationProfile) {
        /* If there is space in the thread's existing buffer then we will return a pointer to that and reduce the
         * remaining space count. Otherwise we will either allocate a new buffer, or (if no space is currently being
         * used in the existing buffer) replace it with a larger one. */

        /* We ensure we allocate a non-zero number of bytes so we can track the allocation. This avoids returning null
         * or reallocating a buffer that we technically have a pointer to. */
        final long allocationSize = alignUp(size);
        if (allocationProfile.profile(remaining >= allocationSize)) {
            final Pointer pointer = new Pointer(cursor(), allocationSize);
            remaining -= allocationSize;
            assert invariants();
            return pointer;
        } else {
            final FiberLocalBuffer newBuffer = allocateNewBlock(language, fiber, allocationSize);
            final Pointer pointer = new Pointer(newBuffer.start.getAddress(), allocationSize);
            newBuffer.remaining -= allocationSize;
            assert newBuffer.invariants();
            return pointer;
        }
    }

    private static long alignUp(long size) {
        return (size + ALIGNMENT_MASK) & ~ALIGNMENT_MASK;
    }

    private FiberLocalBuffer allocateNewBlock(RubyLanguage language, RubyFiber fiber, long size) {
        // Allocate a new buffer. Chain it if we aren't the default thread buffer, otherwise make a new default buffer.
        final long blockSize = Math.max(size, 1024);
        final FiberLocalBuffer newBuffer;
        if (this.parent != null && this.isEmpty()) {
            // Free the old block
            freeMemory(language);
            // Create new bigger block
            newBuffer = new FiberLocalBuffer(Pointer.malloc(blockSize), this.parent);
        } else {
            newBuffer = new FiberLocalBuffer(Pointer.malloc(blockSize), this);
        }
        fiber.ioBuffer = newBuffer;
        return newBuffer;
    }
}
