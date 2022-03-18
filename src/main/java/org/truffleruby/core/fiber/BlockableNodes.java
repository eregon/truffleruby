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
import org.truffleruby.core.klass.RubyClass;
import org.truffleruby.language.Visibility;
import org.truffleruby.language.objects.AllocationTracing;

@CoreModule(value = "Truffle::Blockable", isClass = true)
public abstract class BlockableNodes {

    @CoreMethod(names = { "__allocate__", "__layout_allocate__" }, constructor = true, visibility = Visibility.PRIVATE)
    public abstract static class AllocateNode extends CoreMethodArrayArgumentsNode {

        @Specialization
        protected RubyBlockable allocate(RubyClass rubyClass) {

            final RubyBlockable blocker = new RubyBlockable(
                    rubyClass,
                    getLanguage().blockableShape);
            AllocationTracing.trace(blocker, this);
            return blocker;
        }
    }

    @Primitive(name = "blockable_get_acquire_blocker")
    public abstract static class GetAcquireBlockerNode extends PrimitiveArrayArgumentsNode {

        @Specialization
        protected Object getBlocker(RubyBlockable blocker) {
            return blocker.getAcquireBlocker();
        }
    }

    @Primitive(name = "blockable_set_blocker")
    public abstract static class SetBlockerNode extends PrimitiveArrayArgumentsNode {

        @Specialization
        protected Object setBlocker(RubyBlockable blocker, Object newBlocker) {
            blocker.setBlocker(newBlocker);
            return nil;
        }
    }

    @Primitive(name = "blockable_set_release_blocker")
    public abstract static class SetReleaseBlockerNode extends PrimitiveArrayArgumentsNode {

        @Specialization
        protected Object setBlocker(RubyBlockable blocker, Object newBlocker) {
            blocker.setReleaseBlocker(newBlocker);
            return nil;
        }
    }

    @Primitive(name = "blockable_get_and_set_acquire_blocker")
    public abstract static class GetAndSetAcquireBlockerNode extends PrimitiveArrayArgumentsNode {

        @Specialization
        protected Object getAndSetBlocker(RubyBlockable blocker, Object newBlocker) {
            return blocker.getAndSetAcquireBlocker(newBlocker);
        }
    }

    @Primitive(name = "blockable_get_and_set_release_blocker")
    public abstract static class GetAndSetReleaseBlockerNode extends PrimitiveArrayArgumentsNode {

        @Specialization
        protected Object getAndSetBlocker(RubyBlockable blocker, Object newBlocker) {
            return blocker.getAndSetReleaseBlocker(newBlocker);
        }
    }

    @Primitive(name = "blockable_compare_and_set_blocker")
    public abstract static class CompareAndSetBlockerNode extends PrimitiveArrayArgumentsNode {

        @Specialization
        protected Object getAndSetBlocker(RubyBlockable blocker, Object oldBlocker, Object newBlocker) {
            return blocker.compareAndSetBlocker(oldBlocker, newBlocker);
        }
    }
}
