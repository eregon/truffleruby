/*
 * Copyright (c) 2014, 2021 Oracle and/or its affiliates. All rights reserved. This
 * code is released under a tri EPL/GPL/LGPL license. You can use it,
 * redistribute it and/or modify it under the terms of the:
 *
 * Eclipse Public License version 2.0, or
 * GNU General Public License version 2, or
 * GNU Lesser General Public License version 2.1.
 *
 * Some of the code in this class is modified from org.jruby.runtime.encoding.EncodingService,
 * licensed under the same EPL 2.0/GPL 2.0/LGPL 2.1 used throughout.
 */
package org.truffleruby.core.encoding;

import com.oracle.truffle.api.CompilerDirectives;
import com.oracle.truffle.api.CompilerDirectives.CompilationFinal;
import com.oracle.truffle.api.strings.AbstractTruffleString;
import org.jcodings.Encoding;

import com.oracle.truffle.api.strings.TruffleString;
import org.jcodings.EncodingDB;
import org.truffleruby.core.array.ArrayUtils;
import org.truffleruby.core.rope.CodeRange;
import org.truffleruby.core.rope.NativeRope;
import org.truffleruby.core.rope.Rope;
import org.truffleruby.core.rope.RopeOperations;
import org.truffleruby.core.string.StringAttributes;

public class TStringUtils {

    @CompilationFinal(
            dimensions = 1) private static final TruffleString.Encoding[] JCODING_TO_TSTRING_ENCODINGS = createJCodingToTSEncodingMap();

    public static TruffleString.Encoding jcodingToTEncoding(Encoding jcoding) {
        return JCODING_TO_TSTRING_ENCODINGS[jcoding.getIndex()];
    }

    public static TruffleString fromByteArray(byte[] bytes, TruffleString.Encoding tencoding) {
        return TruffleString.fromByteArrayUncached(bytes, 0, bytes.length, tencoding, false);
    }

    public static TruffleString fromByteArray(byte[] bytes, RubyEncoding rubyEncoding) {
        return TruffleString.fromByteArrayUncached(bytes, 0, bytes.length, rubyEncoding.tencoding, false);
    }

    public static Rope toRope(AbstractTruffleString tstring, RubyEncoding rubyEncoding) {
        var internalArray = tstring.getInternalByteArrayUncached(jcodingToTEncoding(rubyEncoding.jcoding));
        var bytes = ArrayUtils.extractRange(internalArray.getArray(), internalArray.getOffset(),
                internalArray.getOffset() + internalArray.getLength());
        final var rope = RopeOperations.create(bytes, rubyEncoding.jcoding, CodeRange.CR_UNKNOWN);
        assert assertEqual(rope, tstring, rubyEncoding);
        return rope;
    }

    public static TruffleString fromRope(Rope rope, RubyEncoding rubyEncoding) {
        final TruffleString truffleString = fromByteArray(rope.getBytes(), rubyEncoding);
        assert assertEqual(rope, truffleString, rubyEncoding);
        return truffleString;
    }

    private static boolean assertEqual(Rope rope, AbstractTruffleString truffleString, RubyEncoding rubyEncoding) {
        assert truffleString.byteLength(rubyEncoding.tencoding) == rope.byteLength();

        // toString() should never throw
        assert truffleString.toString() != null;

        StringAttributes stringAttributes = null;
        final CodeRange codeRange;
        if (rope instanceof NativeRope) { // ignore the cached CodeRange/characterLength which might not match
            stringAttributes = RopeOperations.calculateCodeRangeAndLength(rope.getEncoding(), rope.getBytes(), 0,
                    rope.byteLength());
            codeRange = stringAttributes.getCodeRange();
        } else {
            codeRange = rope.getCodeRange();
        }
        TruffleString.CodeRange tCodeRange = truffleString.getByteCodeRangeUncached(rubyEncoding.tencoding);
        assert toCodeRange(tCodeRange) == codeRange : codeRange + " vs " + tCodeRange;

        final int characterLength = rope instanceof NativeRope
                ? stringAttributes.getCharacterLength()
                : rope.characterLength();
        assert truffleString.codePointLengthUncached(rubyEncoding.tencoding) == characterLength;
        return true;
    }

    public static CodeRange toCodeRange(TruffleString.CodeRange tCodeRange) {
        switch (tCodeRange) {
            case ASCII:
                return CodeRange.CR_7BIT;
            case VALID:
                return CodeRange.CR_VALID;
            case BROKEN:
                return CodeRange.CR_BROKEN;
            default:
                throw CompilerDirectives.shouldNotReachHere(tCodeRange.name());
        }
    }

    private static TruffleString.Encoding[] createJCodingToTSEncodingMap() {
        var map = new TruffleString.Encoding[EncodingDB.getEncodings().size()];
        for (var entry : EncodingDB.getEncodings()) {
            var jcoding = entry.getEncoding();
            var jcodingName = jcoding.toString();
            final TruffleString.Encoding tsEncoding;
            if (jcodingName.equals("UTF-16")) {
                tsEncoding = TruffleString.Encoding.UTF_16; // is it OK? jcoding one is dummy
            } else if (jcodingName.equals("UTF-32")) {
                tsEncoding = TruffleString.Encoding.UTF_32; // is it OK? jcoding one is dummy
            } else {
                tsEncoding = TruffleString.Encoding.fromJCodingName(jcodingName);
            }
            map[jcoding.getIndex()] = tsEncoding;
        }
        return map;
    }
}
