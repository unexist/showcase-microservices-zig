//
// @package Showcase-Microservices-Zig
//
// @file Todo model
// @copyright 2024-present Christoph Kappel <christoph@unexist.dev>
// @version $Id$
//
// This program can be distributed under the terms of the Apache License v2.0.
// See the file LICENSE for details.
//

const std = @import("std");

alloc: std.mem.Allocator = undefined,
todos: std.AutoHashMap(usize, InternalTodo) = undefined,
lock: std.Thread.Mutex = undefined,
count: usize = 0,

pub const Self = @This();

const InternalTodo = struct {
    id: usize = 0,
    titlebuf: [64]u8,
    titlelen: usize,
    descriptionbuf: [64]u8,
    descriptionlen: usize,
};

pub const Todo = struct {
    id: usize = 0,
    title: []const u8,
    description: []const u8,
};

pub fn init(a: std.mem.Allocator) Self {
    return .{
        .alloc = a,
        .todos = std.AutoHashMap(usize, InternalTodo).init(a),
        .lock = std.Thread.Mutex{},
    };
}

pub fn deinit(self: *Self) void {
    self.todos.deinit();
}

// the request will be freed (and its mem reused by facilio) when it's
// completed, so we take copies of the names
pub fn add(self: *Self, title: ?[]const u8, description: ?[]const u8) !usize {
    var todo: InternalTodo = undefined;
    todo.titlelen = 0;
    todo.descriptionlen = 0;

    if (title) |the_title| {
        @memcpy(todo.titlebuf[0..(the_title.len)], the_title);
        todo.titlelen = the_title.len;
    }

    if (description) |the_description| {
        @memcpy(todo.descriptionbuf[0..(the_description.len)], the_description);
        todo.descriptionlen = the_description.len;
    }

    // We lock only on insertion, deletion, and listing
    self.lock.lock();
    defer self.lock.unlock();
    todo.id = self.count + 1;

    if (self.todos.put(todo.id, todo)) {
        self.count += 1;

        return todo.id;
    } else |err| {
        std.debug.print("add error: {}\n", .{err});

        return err;
    }
}

pub fn delete(self: *Self, id: usize) bool {
    // We lock only on insertion, deletion, and listing
    self.lock.lock();
    defer self.lock.unlock();

    const ret = self.todos.remove(id);
    if (ret) {
        self.count -= 1;
    }

    return ret;
}

pub fn get(self: *Self, id: usize) ?Todo {
    // We don't care about locking here, as our usage-pattern is unlikely to
    // get a todo by id that is not known yet
    if (self.todos.getPtr(id)) |pTodo| {
        return .{
            .id = pTodo.id,
            .first_name = pTodo.titlebuf[0..pTodo.titlelen],
            .last_name = pTodo.descriptionbuf[0..pTodo.descriptionlen],
        };
    }
    std.debug.print("Else part, didnt get todo pointer.\n", .{});

    return null;
}

pub fn update(self: *Self, id: usize, first: ?[]const u8, last: ?[]const u8) bool {
    // we don't care about locking here
    // we update in-place, via getPtr
    if (self.todos.getPtr(id)) |pTodo| {
        pTodo.titlelen = 0;
        pTodo.descriptionlen = 0;

        if (first) |title| {
            @memcpy(pTodo.titlebuf[0..(title.len)], title);
            pTodo.titlelen = title.len;
        }
        if (last) |description| {
            @memcpy(pTodo.descriptionbuf[0..(description.len)], description);
            pTodo.descriptionlen = description.len;
        }
    } else return false;

    return true;
}

pub fn toJSON(self: *Self) ![]const u8 {
    self.lock.lock();
    defer self.lock.unlock();

    // We create a User list that's JSON-friendly
    // NOTE: we could also implement the whole JSON writing ourselves here,
    // working directly with InternalUser elements of the todos hashmap.
    // might actually save some memory
    // TODO: maybe do it directly with the todos.items
    var l: std.ArrayList(Todo) = std.ArrayList(Todo).init(self.alloc);
    defer l.deinit();

    // the potential race condition is fixed by jsonifying with the mutex locked
    var it = JsonTodoIteratorWithRaceCondition.init(&self.todos);
    while (it.next()) |todo| {
        try l.append(todo);
    }
    std.debug.assert(self.todos.count() == l.items.len);
    std.debug.assert(self.count == l.items.len);

    return std.json.stringifyAlloc(self.alloc, l.items, .{});
}

const JsonTodoIteratorWithRaceCondition = struct {
    it: std.AutoHashMap(usize, InternalTodo).ValueIterator = undefined,
    const This = @This();

    // careful:
    // - Self refers to the file's struct
    // - This refers to the JsonUserIterator struct
    pub fn init(internal_users: *std.AutoHashMap(usize, InternalTodo)) This {
        return .{
            .it = internal_users.valueIterator(),
        };
    }

    pub fn next(this: *This) ?Todo {
        if (this.it.next()) |pTodo| {
            // we get a pointer to the internal todo. so it should be safe to
            // create slices from its title and description buffers
            var todo: Todo = .{
                // We don't need .* syntax but want to make it obvious
                .id = pTodo.*.id,
                .title = pTodo.*.titlebuf[0..pTodo.*.titlelen],
                .description = pTodo.*.descriptionbuf[0..pTodo.*.descriptionlen],
            };
            if (pTodo.*.titlelen == 0) {
                todo.title = "";
            }
            if (pTodo.*.descriptionlen == 0) {
                todo.description = "";
            }

            return todo;
        }
        return null;
    }
};
