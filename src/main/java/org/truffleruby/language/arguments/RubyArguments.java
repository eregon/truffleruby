/*
 * Copyright (c) 2013, 2019 Oracle and/or its affiliates. All rights reserved. This
 * code is released under a tri EPL/GPL/LGPL license. You can use it,
 * redistribute it and/or modify it under the terms of the:
 *
 * Eclipse Public License version 2.0, or
 * GNU General Public License version 2, or
 * GNU Lesser General Public License version 2.1.
 */
package org.truffleruby.language.arguments;

import org.truffleruby.core.array.ArrayUtils;
import org.truffleruby.core.proc.RubyProc;
import org.truffleruby.language.control.FrameOnStackMarker;
import org.truffleruby.language.methods.DeclarationContext;
import org.truffleruby.language.methods.InternalMethod;
import org.truffleruby.language.threadlocal.SpecialVariableStorage;

import com.oracle.truffle.api.frame.Frame;
import com.oracle.truffle.api.frame.MaterializedFrame;
import com.oracle.truffle.api.frame.VirtualFrame;
import com.oracle.truffle.api.nodes.ExplodeLoop;

public final class RubyArguments {

    private enum ArgumentIndicies {
        DECLARATION_FRAME, // 0
        CALLER_FRAME, // 1
        CALLER_SPECIAL_VARIABLE_STORAGE, // 2
        METHOD, // 3
        DECLARATION_CONTEXT, // 4
        FRAME_ON_STACK_MARKER, // 5
        SELF, // 6
        BLOCK // 7
    }

    private final static int RUNTIME_ARGUMENT_COUNT = ArgumentIndicies.values().length;

    /** In most cases the DeclarationContext is the one of the InternalMethod. */
    public static Object[] pack(
            MaterializedFrame declarationFrame,
            MaterializedFrame callerFrame,
            SpecialVariableStorage storage,
            InternalMethod method,
            FrameOnStackMarker frameOnStackMarker,
            Object self,
            RubyProc block,
            Object[] arguments) {
        return pack(
                declarationFrame,
                callerFrame,
                storage,
                method,
                method.getDeclarationContext(),
                frameOnStackMarker,
                self,
                block,
                arguments);
    }

    public static Object[] pack(
            MaterializedFrame declarationFrame,
            MaterializedFrame callerFrame,
            SpecialVariableStorage storage,
            InternalMethod method,
            DeclarationContext declarationContext,
            FrameOnStackMarker frameOnStackMarker,
            Object self,
            RubyProc block,
            Object[] arguments) {
        assert method != null;
        assert declarationContext != null;
        assert self != null;
        assert arguments != null;

        final Object[] packed = new Object[RUNTIME_ARGUMENT_COUNT + arguments.length];

        packed[ArgumentIndicies.DECLARATION_FRAME.ordinal()] = declarationFrame;
        packed[ArgumentIndicies.CALLER_FRAME.ordinal()] = callerFrame;
        packed[ArgumentIndicies.CALLER_SPECIAL_VARIABLE_STORAGE.ordinal()] = storage;
        packed[ArgumentIndicies.METHOD.ordinal()] = method;
        packed[ArgumentIndicies.DECLARATION_CONTEXT.ordinal()] = declarationContext;
        packed[ArgumentIndicies.FRAME_ON_STACK_MARKER.ordinal()] = frameOnStackMarker;
        packed[ArgumentIndicies.SELF.ordinal()] = self;
        packed[ArgumentIndicies.BLOCK.ordinal()] = block;

        ArrayUtils.arraycopy(arguments, 0, packed, RUNTIME_ARGUMENT_COUNT, arguments.length);

        return packed;
    }

    // Getters

    public static MaterializedFrame getDeclarationFrame(Frame frame) {
        return (MaterializedFrame) frame.getArguments()[ArgumentIndicies.DECLARATION_FRAME.ordinal()];
    }

    public static MaterializedFrame getCallerFrame(Frame frame) {
        return (MaterializedFrame) frame.getArguments()[ArgumentIndicies.CALLER_FRAME.ordinal()];
    }

    public static SpecialVariableStorage getCallerStorage(Frame frame) {
        return (SpecialVariableStorage) frame.getArguments()[ArgumentIndicies.CALLER_SPECIAL_VARIABLE_STORAGE
                .ordinal()];
    }

    public static InternalMethod getMethod(Frame frame) {
        return (InternalMethod) frame.getArguments()[ArgumentIndicies.METHOD.ordinal()];
    }

    public static DeclarationContext getDeclarationContext(Frame frame) {
        return (DeclarationContext) frame.getArguments()[ArgumentIndicies.DECLARATION_CONTEXT.ordinal()];
    }

    public static FrameOnStackMarker getFrameOnStackMarker(Frame frame) {
        return (FrameOnStackMarker) frame.getArguments()[ArgumentIndicies.FRAME_ON_STACK_MARKER.ordinal()];
    }

    public static Object getSelf(Frame frame) {
        return frame.getArguments()[ArgumentIndicies.SELF.ordinal()];
    }

    public static RubyProc getBlock(Frame frame) {
        return (RubyProc) frame.getArguments()[ArgumentIndicies.BLOCK.ordinal()];
    }

    public static int getArgumentsCount(Frame frame) {
        return frame.getArguments().length - RUNTIME_ARGUMENT_COUNT;
    }

    public static Object getArgument(Frame frame, int index) {
        assert index >= 0 && index < (frame.getArguments().length - RUNTIME_ARGUMENT_COUNT);
        return frame.getArguments()[RUNTIME_ARGUMENT_COUNT + index];
    }

    public static Object[] getArguments(Frame frame) {
        Object[] arguments = frame.getArguments();
        return ArrayUtils.extractRange(arguments, RUNTIME_ARGUMENT_COUNT, arguments.length);
    }

    public static Object[] getArguments(Frame frame, int start) {
        Object[] arguments = frame.getArguments();
        return ArrayUtils.extractRange(arguments, RUNTIME_ARGUMENT_COUNT + start, arguments.length);
    }

    // Getters for the declaration frame that let you reach up several levels

    public static MaterializedFrame getDeclarationFrame(VirtualFrame frame, int level) {
        assert level > 0;
        return getDeclarationFrame(RubyArguments.getDeclarationFrame(frame), level - 1);
    }

    @ExplodeLoop
    public static MaterializedFrame getDeclarationFrame(MaterializedFrame frame, int level) {
        assert frame != null;
        assert level >= 0;

        MaterializedFrame currentFrame = frame;

        for (int n = 0; n < level; n++) {
            currentFrame = RubyArguments.getDeclarationFrame(currentFrame);
        }

        return currentFrame;
    }

    // Getters that fail safely for when you aren't even sure if this is a Ruby frame

    public static MaterializedFrame tryGetDeclarationFrame(Frame frame) {
        if (ArgumentIndicies.DECLARATION_FRAME.ordinal() >= frame.getArguments().length) {
            return null;
        }

        final Object declarationFrame = frame.getArguments()[ArgumentIndicies.DECLARATION_FRAME.ordinal()];

        if (declarationFrame instanceof MaterializedFrame) {
            return (MaterializedFrame) declarationFrame;
        }

        return null;
    }

    public static Object tryGetSelf(Frame frame) {
        if (ArgumentIndicies.SELF.ordinal() >= frame.getArguments().length) {
            return null;
        }

        return frame.getArguments()[ArgumentIndicies.SELF.ordinal()];
    }

    public static RubyProc tryGetBlock(Frame frame) {
        if (ArgumentIndicies.BLOCK.ordinal() >= frame.getArguments().length) {
            return null;
        }

        Object proc = frame.getArguments()[ArgumentIndicies.BLOCK.ordinal()];
        return proc instanceof RubyProc ? (RubyProc) proc : null;
    }

    public static InternalMethod tryGetMethod(Frame frame) {
        if (ArgumentIndicies.METHOD.ordinal() >= frame.getArguments().length) {
            return null;
        }

        final Object method = frame.getArguments()[ArgumentIndicies.METHOD.ordinal()];

        if (method instanceof InternalMethod) {
            return (InternalMethod) method;
        }

        return null;
    }

    public static DeclarationContext tryGetDeclarationContext(Frame frame) {
        if (frame == null) {
            return null;
        }

        if (ArgumentIndicies.DECLARATION_CONTEXT.ordinal() >= frame.getArguments().length) {
            return null;
        }

        final Object declarationContext = frame.getArguments()[ArgumentIndicies.DECLARATION_CONTEXT.ordinal()];

        if (declarationContext instanceof DeclarationContext) {
            return (DeclarationContext) declarationContext;
        }

        return null;
    }

    // Setters

    public static void setDeclarationFrame(Frame frame, MaterializedFrame declarationFrame) {
        frame.getArguments()[ArgumentIndicies.DECLARATION_FRAME.ordinal()] = declarationFrame;
    }

    public static void setDeclarationContext(Frame frame, DeclarationContext declarationContext) {
        frame.getArguments()[ArgumentIndicies.DECLARATION_CONTEXT.ordinal()] = declarationContext;
    }

    public static void setSelf(Frame frame, Object self) {
        frame.getArguments()[ArgumentIndicies.SELF.ordinal()] = self;
    }

    public static void setArgument(Frame frame, int index, Object value) {
        frame.getArguments()[RUNTIME_ARGUMENT_COUNT + index] = value;
    }

}
