/*
 * Copyright (c) 2014, 2019 Oracle and/or its affiliates. All rights reserved. This
 * code is released under a tri EPL/GPL/LGPL license. You can use it,
 * redistribute it and/or modify it under the terms of the:
 *
 * Eclipse Public License version 2.0, or
 * GNU General Public License version 2, or
 * GNU Lesser General Public License version 2.1.
 */
package org.truffleruby.core.cast;

import com.oracle.truffle.api.dsl.Cached;
import com.oracle.truffle.api.dsl.CachedLanguage;
import org.truffleruby.RubyLanguage;
import org.truffleruby.core.rope.Rope;
import org.truffleruby.core.rope.RopeNodes;
import org.truffleruby.core.string.RubyString;
import org.truffleruby.core.symbol.RubySymbol;

import com.oracle.truffle.api.dsl.GenerateUncached;
import com.oracle.truffle.api.dsl.Specialization;
import org.truffleruby.language.RubyBaseNode;

@GenerateUncached
public abstract class ToSymbolNode extends RubyBaseNode {

    public static ToSymbolNode create() {
        return ToSymbolNodeGen.create();
    }

    public static ToSymbolNode getUncached() {
        return ToSymbolNodeGen.getUncached();
    }

    public abstract RubySymbol execute(Object object);

    @Specialization
    protected RubySymbol toSymbolSymbol(RubySymbol symbol) {
        return symbol;
    }

    @Specialization(guards = "str == cachedStr", limit = "getCacheLimit()")
    protected RubySymbol toSymbolJavaString(String str,
            @Cached(value = "str") String cachedStr,
            @CachedLanguage RubyLanguage language,
            @Cached(value = "language.getSymbol(cachedStr)") RubySymbol rubySymbol) {
        return rubySymbol;
    }

    @Specialization(replaces = "toSymbolJavaString")
    protected RubySymbol toSymbolJavaStringUncached(String str,
            @CachedLanguage RubyLanguage language) {
        return language.getSymbol(str);
    }

    @Specialization(guards = "equals.execute(str.rope, cachedRope)", limit = "getCacheLimit()")
    protected RubySymbol toSymbolRubyString(RubyString str,
            @Cached(value = "str.rope") Rope cachedRope,
            @CachedLanguage RubyLanguage language,
            @Cached RopeNodes.EqualNode equals,
            @Cached(value = "language.getSymbol(cachedRope)") RubySymbol rubySymbol) {
        return rubySymbol;
    }

    @Specialization(replaces = "toSymbolRubyString")
    protected RubySymbol toSymbolRubyStringUncached(RubyString str,
            @CachedLanguage RubyLanguage language) {
        return language.getSymbol(str.rope);
    }

    protected int getCacheLimit() {
        return RubyLanguage.getCurrentContext().getOptions().DISPATCH_CACHE;
    }
}
