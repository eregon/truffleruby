/*
 * Copyright (c) 2022 Oracle and/or its affiliates. All rights reserved. This
 * code is released under a tri EPL/GPL/LGPL license. You can use it,
 * redistribute it and/or modify it under the terms of the:
 *
 * Eclipse Public License version 2.0, or
 * GNU General Public License version 2, or
 * GNU Lesser General Public License version 2.1.
 */
package org.truffleruby.core.fiber;

import java.lang.invoke.MethodHandles;
import java.lang.invoke.VarHandle;
import java.util.Set;

import com.oracle.truffle.api.object.Shape;

import org.truffleruby.core.klass.RubyClass;
import org.truffleruby.language.Nil;
import org.truffleruby.language.RubyDynamicObject;
import org.truffleruby.language.objects.ObjectGraphNode;

public class RubyBlockable extends RubyDynamicObject implements ObjectGraphNode {

    private static final VarHandle BLOCKER_HANDLE;
    static {
        try {
            BLOCKER_HANDLE = MethodHandles.lookup().findVarHandle(RubyBlockable.class, "blocker", Object.class);
        } catch (NoSuchFieldException | IllegalAccessException e) {
            throw new Error(e);
        }
    }

    @SuppressWarnings("unused") private volatile Object blocker = Nil.INSTANCE;

    public RubyBlockable(
            RubyClass rubyClass,
            Shape shape) {
        super(rubyClass, shape);
    }

    public Object getBlocker() {
        return BLOCKER_HANDLE.getVolatile(this);
    }

    public Object getAcquireBlocker() {
        return BLOCKER_HANDLE.getAcquire(this);
    }

    public boolean compareAndSetBlocker(Object oldBlocker, Object newBlocker) {
        return BLOCKER_HANDLE.compareAndSet(this, oldBlocker, newBlocker);
    }

    public Object getAndSetBlocker(Object newBlocker) {
        return BLOCKER_HANDLE.getAndSet(this, newBlocker);
    }

    public Object getAndSetAcquireBlocker(Object newBlocker) {
        return BLOCKER_HANDLE.getAndSetAcquire(this, newBlocker);
    }

    public Object getAndSetReleaseBlocker(Object newBlocker) {
        return BLOCKER_HANDLE.getAndSetRelease(this, newBlocker);
    }

    public void setBlocker(Object newBlocker) {
        BLOCKER_HANDLE.setVolatile(this, newBlocker);
    }

    public void setReleaseBlocker(Object newBlocker) {
        BLOCKER_HANDLE.setRelease(this, newBlocker);
    }

    @Override
    public void getAdjacentObjects(Set<Object> reachable) {
        reachable.add(blocker);
    }


}
