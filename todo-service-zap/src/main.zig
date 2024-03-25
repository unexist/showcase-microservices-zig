//
// @package Showcase-Microservices-Zig
//
// @file Todo application
// @copyright 2024-present Christoph Kappel <christoph@unexist.dev>
// @version $Id$
//
// This program can be distributed under the terms of the Apache License v2.0.
// See the file LICENSE for details.
//

const std = @import("std");
const zap = @import("zap");
const TodoEndpoints = @import("adapter/todoendpoints.zig");

fn on_request(r: zap.Request) void {
    if (r.path) |the_path| {
        std.debug.print("PATH: {s}\n", .{the_path});
    }

    if (r.query) |the_query| {
        std.debug.print("QUERY: {s}\n", .{the_query});
    }
    r.sendBody("<html><body><h1>Hello from ZAP!!!</h1></body></html>") catch return;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    var allocator = gpa.allocator();

    // Scoped, so that memory leak, if any can be detected later
    {
        var listener = zap.Endpoint.Listener.init(
            allocator,
            .{
                .port = 3000,
                .on_request = on_request,
                .log = true,
                .max_clients = 100000,
                .max_body_size = 100 * 1024 * 1024,
            },
        );
        defer listener.deinit();
        var todoendpoints = TodoEndpoints.init(allocator, "/todos");
        defer todoendpoints.deinit();

        try listener.register(todoendpoints.endpoint());
        try listener.listen();

        std.debug.print("Listening on 0.0.0.0:3000\n", .{});

        // Start worker threads
        zap.start(.{
            .threads = 1,
            .workers = 2,
        });
    }
    // Show potential memory leaks when ZAP is shut down
    const has_leaked = gpa.detectLeaks();
    std.log.debug("Has leaked: {}\n", .{has_leaked});
}