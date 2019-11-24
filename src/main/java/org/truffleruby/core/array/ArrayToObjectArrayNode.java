/*
 * Copyright (c) 2016, 2019 Oracle and/or its affiliates. All rights reserved. This
 * code is released under a tri EPL/GPL/LGPL license. You can use it,
 * redistribute it and/or modify it under the terms of the:
 *
 * Eclipse Public License version 2.0, or
 * GNU General Public License version 2, or
 * GNU Lesser General Public License version 2.1.
 */
package org.truffleruby.core.array;

import com.oracle.truffle.api.profiles.ConditionProfile;
import org.truffleruby.Layouts;
import org.truffleruby.language.RubyBaseNode;
import org.truffleruby.language.RubyGuards;

import com.oracle.truffle.api.dsl.Cached;
import com.oracle.truffle.api.dsl.ImportStatic;
import com.oracle.truffle.api.dsl.Specialization;
import com.oracle.truffle.api.object.DynamicObject;
import org.truffleruby.language.objects.ReadObjectFieldNode;

@ImportStatic(ArrayGuards.class)
public abstract class ArrayToObjectArrayNode extends RubyBaseNode {

    public static ArrayToObjectArrayNode create() {
        return ArrayToObjectArrayNodeGen.create();
    }

    private final ConditionProfile nonEmptyProfile = ConditionProfile.createBinaryProfile();
    private final ConditionProfile isHashProfile = ConditionProfile.createBinaryProfile();
    private final ConditionProfile hasFlagProfile = ConditionProfile.createBinaryProfile();
    @Child ReadObjectFieldNode readObjectFieldNode = ReadObjectFieldNode.create();

    public Object[] unsplat(Object[] arguments) {
        assert arguments.length == 1;
        assert RubyGuards.isRubyArray(arguments[0]);
        final Object[] array = executeToObjectArray((DynamicObject) arguments[0]);

        if (nonEmptyProfile.profile(array.length > 0)) {
            final Object last = array[array.length - 1];
            if (isHashProfile.profile(RubyGuards.isRubyHash(last)) &&
                    hasFlagProfile.profile((boolean) readObjectFieldNode.execute((DynamicObject) last, Layouts.RUBY2_KEYWORDS_IDENTIFIER, false))) {
                throw new Error("ruby2_keywords");
            }
        }

        return array;
    }

    public abstract Object[] executeToObjectArray(DynamicObject array);

    @Specialization(guards = "strategy.matches(array)", limit = "STORAGE_STRATEGIES")
    protected Object[] toObjectArrayOther(DynamicObject array,
            @Cached("of(array)") ArrayStrategy strategy,
            @Cached("strategy.boxedCopyNode()") ArrayOperationNodes.ArrayBoxedCopyNode boxedCopyNode) {
        final int size = strategy.getSize(array);
        return boxedCopyNode.execute(Layouts.ARRAY.getStore(array), size);
    }

}
