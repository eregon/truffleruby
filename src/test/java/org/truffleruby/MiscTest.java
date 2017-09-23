/*
 * Copyright (c) 2017 Oracle and/or its affiliates. All rights reserved. This
 * code is released under a tri EPL/GPL/LGPL license. You can use it,
 * redistribute it and/or modify it under the terms of the:
 *
 * Eclipse Public License version 1.0
 * GNU General Public License version 2
 * GNU Lesser General Public License version 2.1
 */
package org.truffleruby;

import org.graalvm.polyglot.Context;
import org.graalvm.polyglot.PolyglotException;
import org.graalvm.polyglot.Value;
import org.junit.Assert;
import org.junit.Ignore;
import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotEquals;
import static org.junit.Assert.assertTrue;

import java.util.Timer;
import java.util.TimerTask;

public class MiscTest {

    @Test
    public void testMembersAndStringUnboxing() {
        try (Context context = Context.create()) {
            Value result = context.eval("ruby", "Truffle::Interop.object_literal(id: 42, text: '42', arr: [1,42,3])");
            assertTrue(result.hasMembers());

            int id = result.getMember("id").asInt();
            assertEquals(42, id);

            String text = result.getMember("text").asString();
            assertEquals("42", text);

            Value array = result.getMember("arr");
            assertTrue(array.hasArrayElements());
            assertEquals(3, array.getArraySize());
            assertEquals(42, array.getArrayElement(1).asInt());
        }
    }

    @Test
    public void timeoutExecution() {
        Context context = Context.create();

        Timer timer = new Timer();
        // schedule a timeout in 1s
        timer.schedule(new TimerTask() {
            @Override
            public void run() {
                try {
                    context.close(true);
                } catch (PolyglotException e) {
                    assertTrue(e.isCancelled());
                }
            }
        }, 1000);

        try {
            String maliciousCode = "while true; end";
            context.eval("ruby", maliciousCode);
            Assert.fail();
        } catch (PolyglotException e) {
            assertTrue(e.isCancelled());
        }
    }

    @Test
    public void testEvalFromIntegratorThreadSingleThreaded() throws InterruptedException {
        final String codeDependingOnCurrentThread = "Thread.current.object_id";

        try (Context context = Context.create()) {
            long thread1 = context.eval("ruby", codeDependingOnCurrentThread).asLong();

            Thread thread = new Thread(() -> {
                long thread2 = context.eval("ruby", codeDependingOnCurrentThread).asLong();
                assertNotEquals(thread1, thread2);
            });
            thread.start();
            thread.join();
        }
    }

    @Ignore("Truffle considers Fibers threads as multithreading currently")
    @Test
    public void testFiberFromIntegratorThread() throws InterruptedException {
        try (Context context = Context.newBuilder().allowCreateThread(true).build()) {
            context.eval("ruby", ":init");

            Thread thread = new Thread(() -> {
                int value = context.eval("ruby", "Fiber.new { 6 * 7 }.resume").asInt();
                assertEquals(42, value);
            });
            thread.start();
            thread.join();
        }
    }

    @Test
    public void testSharingSingleThreaded() throws InterruptedException {
        try (Context context = Context.create()) {
            boolean shared1 = context.eval("ruby", "BAR=Object.new; Truffle::Debug.shared?(BAR)").asBoolean();
            assertFalse(shared1);

            Thread thread = new Thread(() -> {
                boolean shared2 = context.eval("ruby", "FOO = Object.new; Truffle::Debug.shared?(FOO)").asBoolean();
                assertFalse(shared2);
            });
            thread.start();
            thread.join();
        }
    }

    @Test
    public void testSharingGuestMultiThreaded() {
        try (Context context = Context.newBuilder().allowCreateThread(true).build()) {
            context.eval("ruby", "$done = false");

            context.eval("ruby", "Thread.new { FOO = Object.new }.join");
            boolean shared = context.eval("ruby", "Truffle::Debug.shared?(FOO)").asBoolean();
            assertTrue(shared);
        }
    }

    @Test
    public void testSharingHostMultiThreaded() {
        try (Context context = Context.create()) {
            context.eval("ruby", "$done = false");

            Thread thread1 = new Thread(() -> {
                context.eval("ruby", "$other_thread = Thread.current; Thread.pass until $done");
            });

            Thread thread2 = new Thread(() -> {
                boolean shared = context.eval("ruby",
                        "Thread.pass until $other_thread\n" +
                                "FOO = Object.new\n" +
                                "$done = true\n" +
                                "Truffle::Debug.shared?(FOO)").asBoolean();
                assertTrue(shared);
            });

            thread1.start();
            thread2.start();

            pollWhileInterrupted(context, thread1::join);
            pollWhileInterrupted(context, thread2::join);
        }
    }

    private interface BlockingAction {
        void block() throws InterruptedException;
    }

    private void pollWhileInterrupted(Context context, BlockingAction action) {
        while (true) {
            try {
                action.block();
                break;
            } catch (InterruptedException e) {
                context.eval("ruby", ":poll_for_safepoint");
            }
        }
    }

}
