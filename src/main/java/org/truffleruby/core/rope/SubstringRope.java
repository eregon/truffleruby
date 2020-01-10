/*
 * Copyright (c) 2015, 2019 Oracle and/or its affiliates. All rights reserved. This
 * code is released under a tri EPL/GPL/LGPL license. You can use it,
 * redistribute it and/or modify it under the terms of the:
 *
 * Eclipse Public License version 2.0, or
 * GNU General Public License version 2, or
 * GNU Lesser General Public License version 2.1.
 */

package org.truffleruby.core.rope;

import org.jcodings.Encoding;

import com.oracle.truffle.api.CompilerDirectives;
import org.jcodings.specific.ASCIIEncoding;

public class SubstringRope extends ManagedRope {

    private final ManagedRope child;
    private final int byteOffset;

    public SubstringRope(
            Encoding encoding,
            ManagedRope child,
            int offset,
            int byteLength,
            int characterLength,
            CodeRange codeRange) {
        // TODO (nirvdrum 07-Jan-16) Verify that this rope is only used for character substrings and not arbitrary byte slices. The former should always have the child's code range while the latter may not.
        this(child, encoding, offset, byteLength, characterLength, codeRange);
    }

    private SubstringRope(
            ManagedRope child,
            Encoding encoding,
            int byteOffset,
            int byteLength,
            int characterLength,
            CodeRange codeRange) {
        // TODO (nirvdrum 07-Jan-16) Verify that this rope is only used for character substrings and not arbitrary byte slices. The former should always have the child's code range while the latter may not.
        super(encoding, codeRange, byteLength, characterLength, child.depth() + 1, null);
        this.child = child;
        this.byteOffset = byteOffset;

        assert byteLength <= child.byteLength();
    }

    @Override
    Rope withEncoding7bit(Encoding newEncoding) {
        assert getCodeRange() == CodeRange.CR_7BIT;
        return new SubstringRope(
                getChild(),
                newEncoding,
                getByteOffset(),
                byteLength(),
                characterLength(),
                CodeRange.CR_7BIT);
    }

    @Override
    Rope withBinaryEncoding() {
        assert getCodeRange() == CodeRange.CR_VALID;
        return new SubstringRope(
                getChild(),
                ASCIIEncoding.INSTANCE,
                getByteOffset(),
                byteLength(),
                byteLength(),
                CodeRange.CR_VALID);
    }

    @Override
    protected byte[] getBytesSlow() {
        if (child.getRawBytes() != null) {
            final byte[] ret = new byte[byteLength()];

            System.arraycopy(child.getRawBytes(), byteOffset, ret, 0, byteLength());

            return ret;
        }

        return RopeOperations.flattenBytes(this);
    }

    @Override
    public byte getByteSlow(int index) {
        return child.getByteSlow(index + byteOffset);
    }

    public ManagedRope getChild() {
        return child;
    }

    public int getByteOffset() {
        return byteOffset;
    }

}
