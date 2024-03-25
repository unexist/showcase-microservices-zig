//
// @package Showcase-Microservices-Zig
//
// @file Todo endpoints
// @copyright 2024-present Christoph Kappel <christoph@unexist.dev>
// @version $Id$
//
// This program can be distributed under the terms of the Apache License v2.0.
// See the file LICENSE for details.
//

const std = @import("std");
const zap = @import("zap");
const Todos = @import("../domain/todo.zig");
const Todo = Todos.Todo;

// an Endpoint

pub const Self = @This();

alloc: std.mem.Allocator = undefined,
ep: zap.Endpoint = undefined,
_todos: Todos = undefined,

pub fn init(
    a: std.mem.Allocator,
    todo_path: []const u8,
) Self {
    return .{
        .alloc = a,
        ._todos = Todos.init(a),
        .ep = zap.Endpoint.init(.{
            .path = todo_path,
            .get = getTodo,
            .post = postTodo,
            .put = putTodo,
            .patch = putTodo,
            .delete = deleteTodo,
            .options = optionsTodo,
        }),
    };
}

pub fn deinit(self: *Self) void {
    self._todos.deinit();
}

pub fn todos(self: *Self) *Todos {
    return &self._todos;
}

pub fn endpoint(self: *Self) *zap.Endpoint {
    return &self.ep;
}

fn todoIdFromPath(self: *Self, path: []const u8) ?usize {
    if (path.len >= self.ep.settings.path.len + 2) {
        if (path[self.ep.settings.path.len] != '/') {
            return null;
        }

        const idstr = path[self.ep.settings.path.len + 1 ..];

        return std.fmt.parseUnsigned(usize, idstr, 10) catch null;
    }

    return null;
}

fn getTodo(e: *zap.Endpoint, r: zap.Request) void {
    const self = @fieldParentPtr(Self, "ep", e);

    if (r.path) |path| {
        // /todos
        if (path.len == e.settings.path.len) {
            return self.listTodos(r);
        }

        var jsonbuf: [256]u8 = undefined;
        if (self.todoIdFromPath(path)) |id| {
            if (self._todos.get(id)) |todo| {
                if (zap.stringifyBuf(&jsonbuf, todo, .{})) |json| {
                    r.sendJson(json) catch return;
                }
            }
        } else {
            r.setStatusNumeric(404);
            r.sendBody("") catch return;
        }
    }
}

fn listTodos(self: *Self, r: zap.Request) void {
    if (self._todos.toJSON()) |json| {
        defer self.alloc.free(json);

        r.sendJson(json) catch return;
    } else |err| {
        std.debug.print("LIST error: {}\n", .{err});
    }
}

fn postTodo(e: *zap.Endpoint, r: zap.Request) void {
    const self = @fieldParentPtr(Self, "ep", e);

    if (r.body) |body| {
        var maybe_todo: ?std.json.Parsed(Todo) = std.json.parseFromSlice(Todo, self.alloc, body, .{}) catch null;
        if (maybe_todo) |t| {
            defer t.deinit();

            if (self._todos.add(t.value.title, u.value.description)) |id| {
                var location = [_]u8{undefined} ** 100;
                const locationvalue = std.fmt.bufPrint(&location, "/todos/{}", .{id}) catch return;

                r.setStatusNumeric(201);
                r.setHeader("Location", locationvalue) catch return;
                r.sendBody("") catch return;
            } else |err| {
                std.debug.print("ADDING error: {}\n", .{err});

                return;
            }
        } else std.debug.print("parse error. maybe_todo is null\n", .{});
    }
}

fn putTodo(e: *zap.Endpoint, r: zap.Request) void {
    const self = @fieldParentPtr(Self, "ep", e);

    if (r.path) |path| {
        if (self.todoIdFromPath(path)) |id| {
            if (self._todos.get(id)) |_| {
                if (r.body) |body| {
                    var maybe_todo: ?std.json.Parsed(Todo) = std.json.parseFromSlice(Todo, self.alloc, body, .{}) catch null;

                    if (maybe_todo) |u| {
                        defer u.deinit();

                        if (self._todos.update(id, u.value.title, u.value.description)) {
                            var location = [_]u8{undefined} ** 100;
                            const locationvalue = std.fmt.bufPrint(&location, "/todos/{}", .{id}) catch return;

                            r.setStatusNumeric(204);
                            r.setHeader("Location", locationvalue) catch return;
                            r.sendBody("") catch return;
                        } else {
                            var jsonbuf: [128]u8 = undefined;
                            if (zap.stringifyBuf(&jsonbuf, .{ .status = "ERROR", .id = id }, .{})) |json| {
                                r.sendJson(json) catch return;
                            }
                        }
                    }
                }
            } else {
                r.setStatusNumeric(404);
                r.sendBody("") catch return;
            }
        }
    }
}

fn deleteTodo(e: *zap.Endpoint, r: zap.Request) void {
    const self = @fieldParentPtr(Self, "ep", e);

    if (r.path) |path| {
        if (self.todoIdFromPath(path)) |id| {
            if (self._todos.delete(id)) {
                r.setStatusNumeric(204);
                r.sendBody("") catch return;
            } else {
                r.setStatusNumeric(404);
                r.sendBody("") catch return;
            }
        }
    }
}

fn optionsTodo(e: *zap.Endpoint, r: zap.Request) void {
    _ = e;
    r.setHeader("Access-Control-Allow-Origin", "*") catch return;
    r.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS") catch return;
    r.setStatus(zap.StatusCode.no_content);
    r.markAsFinished(true);
}
