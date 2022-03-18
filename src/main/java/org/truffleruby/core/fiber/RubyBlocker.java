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

import java.util.Set;

import org.truffleruby.language.ImmutableRubyObject;
import org.truffleruby.language.objects.ObjectGraphNode;

public class RubyBlocker extends ImmutableRubyObject implements ObjectGraphNode {

    private final RubyBlocker successor;
    private final RubyFiber fiber;

    public RubyBlocker(RubyBlocker successor, RubyFiber fiber) {
        this.successor = successor;
        this.fiber = fiber;
    }

    public RubyBlocker getSuccessor() {
        return successor;
    }

    public RubyFiber getFiber() {
        return fiber;
    }

    public boolean isEmpty() {
        return successor == null;
    }

    public void getAdjacentObjects(Set<Object> reachable) {
        if (successor != null) {
            reachable.add(successor);
        }
        if (fiber != null) {
            reachable.add(fiber);
        }
    }
}
