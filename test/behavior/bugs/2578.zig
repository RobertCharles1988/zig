const builtin = @import("builtin");

const Foo = struct {
    y: u8,
};

var foo: Foo = undefined;
const t = &foo;

fn bar(pointer: ?*anyopaque) void {
    _ = pointer;
}

test "fixed" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

    bar(t);
}
