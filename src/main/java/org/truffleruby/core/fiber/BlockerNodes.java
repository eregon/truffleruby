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

import com.oracle.truffle.api.dsl.Specialization;

import org.truffleruby.builtins.CoreMethod;
import org.truffleruby.builtins.CoreMethodArrayArgumentsNode;
import org.truffleruby.builtins.CoreModule;
import org.truffleruby.builtins.Primitive;
import org.truffleruby.builtins.PrimitiveArrayArgumentsNode;
import org.truffleruby.language.Nil;

@CoreModule(value = "Truffle::Blocker", isClass = true)
public abstract class BlockerNodes {


    @Primitive(name = "blocker_create")
    public abstract static class AllocateNode extends PrimitiveArrayArgumentsNode {

        @Specialization
        protected RubyBlocker create(RubyBlocker successor, RubyFiber fiber) {

            final RubyBlocker blocker = new RubyBlocker(successor, fiber);
            return blocker;
        }

        @Specialization
        protected RubyBlocker create(Nil successor, Nil fiber) {

            final RubyBlocker blocker = new RubyBlocker(null, null);
            return blocker;
        }
    }

    @CoreMethod(names = "successor")
    public abstract static class SuccessorNode extends CoreMethodArrayArgumentsNode {

        @Specialization
        protected RubyBlocker successor(RubyBlocker blocker) {
            return blocker.getSuccessor();
        }
    }

    @CoreMethod(names = "fiber")
    public abstract static class FiberNOde extends CoreMethodArrayArgumentsNode {

        @Specialization
        protected RubyFiber fiber(RubyBlocker blocker) {
            return blocker.getFiber();
        }
    }

    @CoreMethod(names = "empty?")
    public abstract static class IsEmptyNode extends CoreMethodArrayArgumentsNode {

        @Specialization
        protected boolean isEmpty(RubyBlocker blocker) {
            return blocker.isEmpty();
        }
    }


}
