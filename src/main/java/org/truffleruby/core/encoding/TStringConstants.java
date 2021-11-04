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

import org.truffleruby.core.rope.RopeConstants;

import com.oracle.truffle.api.strings.TruffleString;

public class TStringConstants {

    public static final TruffleString EMPTY_ASCII_8BIT_TSTRING = withHashCode(
            TStringUtils.fromByteArray(RopeConstants.EMPTY_BYTES, Encodings.BINARY));
    public static final TruffleString EMPTY_US_ASCII_TSTRING = withHashCode(
            TStringUtils.fromByteArray(RopeConstants.EMPTY_BYTES, Encodings.US_ASCII));
    public static final TruffleString EMPTY_UTF8_TSTRING = withHashCode(
            TStringUtils.fromByteArray(RopeConstants.EMPTY_BYTES, Encodings.UTF_8));

    private static <T> T withHashCode(T object) {
        object.hashCode();
        return object;
    }

}
