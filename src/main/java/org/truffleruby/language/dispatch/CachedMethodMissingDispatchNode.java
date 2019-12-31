/*
 * Copyright (c) 2014, 2019 Oracle and/or its affiliates. All rights reserved. This
 * code is released under a tri EPL/GPL/LGPL license. You can use it,
 * redistribute it and/or modify it under the terms of the:
 *
 * Eclipse Public License version 2.0, or
 * GNU General Public License version 2, or
 * GNU Lesser General Public License version 2.1.
 */
package org.truffleruby.language.dispatch;

import org.truffleruby.RubyContext;
import org.truffleruby.core.array.ArrayUtils;
import org.truffleruby.core.module.MethodLookupResult;
import org.truffleruby.core.rope.RopeNodes;
import org.truffleruby.core.string.StringOperations;
import org.truffleruby.language.RubyGuards;
import org.truffleruby.language.methods.InternalMethod;
import org.truffleruby.language.objects.MetaClassNode;

import com.oracle.truffle.api.Assumption;
import com.oracle.truffle.api.CompilerDirectives;
import com.oracle.truffle.api.CompilerDirectives.CompilationFinal;
import com.oracle.truffle.api.Truffle;
import com.oracle.truffle.api.frame.VirtualFrame;
import com.oracle.truffle.api.nodes.DirectCallNode;
import com.oracle.truffle.api.nodes.InvalidAssumptionException;
import com.oracle.truffle.api.object.DynamicObject;

public class CachedMethodMissingDispatchNode extends CachedDispatchNode {

    private final DynamicObject expectedClass;
    @CompilationFinal(dimensions = 1) private final Assumption[] originalMethodAssumptions;
    @CompilationFinal(dimensions = 1) private final Assumption[] methodMissingAssumptions;
    private final InternalMethod methodMissing;

    @Child private MetaClassNode metaClassNode;
    @Child private DirectCallNode callNode;

    private final DynamicObject cachedNameAsSymbol;

    public CachedMethodMissingDispatchNode(
            RubyContext context,
            Object cachedName,
            DispatchNode next,
            DynamicObject expectedClass,
            MethodLookupResult originalMethodLookup,
            MethodLookupResult methodMissingLookup,
            DispatchAction dispatchAction) {
        super(context, cachedName, next, dispatchAction);

        this.expectedClass = expectedClass;
        this.originalMethodAssumptions = originalMethodLookup.getAssumptions();
        this.methodMissingAssumptions = methodMissingLookup.getAssumptions();
        this.methodMissing = methodMissingLookup.getMethod();
        this.metaClassNode = MetaClassNode.create();
        this.callNode = Truffle.getRuntime().createDirectCallNode(methodMissing.getCallTarget());

        if (RubyGuards.isRubySymbol(cachedName)) {
            cachedNameAsSymbol = (DynamicObject) cachedName;
        } else if (RubyGuards.isRubyString(cachedName)) {
            cachedNameAsSymbol = context.getSymbolTable().getSymbol(StringOperations.rope((DynamicObject) cachedName));
        } else if (cachedName instanceof String) {
            cachedNameAsSymbol = context.getSymbolTable().getSymbol((String) cachedName);
        } else {
            throw new UnsupportedOperationException();
        }
    }

    @Override
    protected void applySplittingInliningStrategy(DirectCallNode callNode, InternalMethod method) {
        /*
         * The way that #method_missing is used is usually as an indirection to call some other
         * method, and possibly to modify the arguments. In both cases, but especially the latter,
         * it makes a lot of sense to manually clone the call target and to inline it.
         */
        if (callNode.isCallTargetCloningAllowed() && (getContext().getOptions().METHODMISSING_ALWAYS_CLONE ||
                method.getSharedMethodInfo().shouldAlwaysClone())) {
            insert(callNode);
            callNode.cloneCallTarget();
        }

        if (callNode.isInlinable() && getContext().getOptions().METHODMISSING_ALWAYS_INLINE) {
            insert(callNode);
            callNode.forceInlining();
        }
    }

    @Override
    protected void reassessSplittingInliningStrategy() {
        applySplittingInliningStrategy(callNode, methodMissing);
    }

    @Override
    protected boolean guard(Object methodName, Object receiver) {
        return guardName(methodName) &&
                metaClassNode.executeMetaClass(receiver) == expectedClass;
    }

    @Override
    public Object executeDispatch(
            VirtualFrame frame,
            Object receiverObject,
            Object methodName,
            DynamicObject blockObject,
            Object[] argumentsObjects) {
        try {
            checkAssumptions(originalMethodAssumptions);
            checkAssumptions(methodMissingAssumptions);
        } catch (InvalidAssumptionException e) {
            return resetAndDispatch(
                    frame,
                    receiverObject,
                    methodName,
                    blockObject,
                    argumentsObjects,
                    "class modified");
        }

        if (!guard(methodName, receiverObject)) {
            return next.executeDispatch(
                    frame,
                    receiverObject,
                    methodName,
                    blockObject,
                    argumentsObjects);
        }

        switch (getDispatchAction()) {
            case CALL_METHOD:
                // When calling #method_missing we need to prepend the symbol
                final Object[] modifiedArgumentsObjects = ArrayUtils.unshift(argumentsObjects, cachedNameAsSymbol);

                return call(callNode, frame, methodMissing, receiverObject, blockObject, modifiedArgumentsObjects);

            case RESPOND_TO_METHOD:
                return false;

            default:
                CompilerDirectives.transferToInterpreterAndInvalidate();
                throw new UnsupportedOperationException();
        }
    }

}
