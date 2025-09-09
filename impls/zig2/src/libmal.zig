//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub fn rep(inpt: []u8) []u8 {
    return PRINT(EVAL(READ(inpt)));
}

fn READ(inpt: []u8) []u8 {
    return inpt;
}

fn EVAL(inpt: []u8) []u8 {
    return inpt;
}

fn PRINT(inpt: []u8) []u8 {
    return inpt;
}
