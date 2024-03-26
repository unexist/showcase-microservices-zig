//
// @package Showcase-Microservices-Zig
//
// @file Todo repository
// @copyright 2024-present Christoph Kappel <christoph@unexist.dev>
// @version $Id$
//
// This program can be distributed under the terms of the Apache License v2.0.
// See the file LICENSE for details.
//

const todo = @import("todo.zig");

const Repository = struct {
    // Open connection to database                                                                                                                                                                                                                                                                                [2/1876]
    open: fn (*Repository, []const u8) void,

    // Get all todos stored by this repository
    getTodos: fn (*Repository, ?[]todo.Todo) void,

    // Create new todo based on given values
    createTodo: fn (*Repository, ?todo.Todo) void,

    // Get todo entry with given id
    getTodo: fn (*Repository, usize) ?todo.Todo,

    // Update todo entry with given id
    updateTodo: fn (*Repository, ?todo.Todo) void,

    // Delete todo entry with given id
    deleteTodo: fn (*Repository, usize) void,

    // Clear table
    clear: fn (*Repository) void,

    // Close database connection
    close: fn (*Repository) void,
};