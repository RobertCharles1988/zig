// Ported from:
//
// https://github.com/llvm/llvm-project/commit/d674d96bc56c0f377879d01c9d8dfdaaa7859cdb/compiler-rt/lib/builtins/comparesf2.c

const std = @import("std");
const builtin = @import("builtin");

const LE = enum(i32) {
    Less = -1,
    Equal = 0,
    Greater = 1,

    const Unordered: LE = .Greater;
};

const GE = enum(i32) {
    Less = -1,
    Equal = 0,
    Greater = 1,

    const Unordered: GE = .Less;
};

pub inline fn cmp(comptime T: type, comptime RT: type, a: T, b: T) RT {
    @setRuntimeSafety(builtin.is_test);

    const bits = @typeInfo(T).Float.bits;
    const srep_t = std.meta.Int(.signed, bits);
    const rep_t = std.meta.Int(.unsigned, bits);

    const significandBits = std.math.floatMantissaBits(T);
    const exponentBits = std.math.floatExponentBits(T);
    const signBit = (@as(rep_t, 1) << (significandBits + exponentBits));
    const absMask = signBit - 1;
    const infT = comptime std.math.inf(T);
    const infRep = @bitCast(rep_t, infT);

    const aInt = @bitCast(srep_t, a);
    const bInt = @bitCast(srep_t, b);
    const aAbs = @bitCast(rep_t, aInt) & absMask;
    const bAbs = @bitCast(rep_t, bInt) & absMask;

    // If either a or b is NaN, they are unordered.
    if (aAbs > infRep or bAbs > infRep) return RT.Unordered;

    // If a and b are both zeros, they are equal.
    if ((aAbs | bAbs) == 0) return .Equal;

    // If at least one of a and b is positive, we get the same result comparing
    // a and b as signed integers as we would with a floating-point compare.
    if ((aInt & bInt) >= 0) {
        if (aInt < bInt) {
            return .Less;
        } else if (aInt == bInt) {
            return .Equal;
        } else return .Greater;
    } else {
        // Otherwise, both are negative, so we need to flip the sense of the
        // comparison to get the correct result.  (This assumes a twos- or ones-
        // complement integer representation; if integers are represented in a
        // sign-magnitude representation, then this flip is incorrect).
        if (aInt > bInt) {
            return .Less;
        } else if (aInt == bInt) {
            return .Equal;
        } else return .Greater;
    }
}

pub inline fn unordcmp(comptime T: type, a: T, b: T) i32 {
    @setRuntimeSafety(builtin.is_test);

    const rep_t = std.meta.Int(.unsigned, @typeInfo(T).Float.bits);

    const significandBits = std.math.floatMantissaBits(T);
    const exponentBits = std.math.floatExponentBits(T);
    const signBit = (@as(rep_t, 1) << (significandBits + exponentBits));
    const absMask = signBit - 1;
    const infRep = @bitCast(rep_t, std.math.inf(T));

    const aAbs: rep_t = @bitCast(rep_t, a) & absMask;
    const bAbs: rep_t = @bitCast(rep_t, b) & absMask;

    return @boolToInt(aAbs > infRep or bAbs > infRep);
}

// Comparison between f32

pub fn __lesf2(a: f32, b: f32) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);
    const float = cmp(f32, LE, a, b);
    return @bitCast(i32, float);
}

pub fn __gesf2(a: f32, b: f32) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);
    const float = cmp(f32, GE, a, b);
    return @bitCast(i32, float);
}

pub fn __eqsf2(a: f32, b: f32) callconv(.C) i32 {
    return __lesf2(a, b);
}

pub fn __ltsf2(a: f32, b: f32) callconv(.C) i32 {
    return __lesf2(a, b);
}

pub fn __nesf2(a: f32, b: f32) callconv(.C) i32 {
    return __lesf2(a, b);
}

pub fn __gtsf2(a: f32, b: f32) callconv(.C) i32 {
    return __gesf2(a, b);
}

// Comparison between f64

pub fn __ledf2(a: f64, b: f64) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);
    const float = cmp(f64, LE, a, b);
    return @bitCast(i32, float);
}

pub fn __gedf2(a: f64, b: f64) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);
    const float = cmp(f64, GE, a, b);
    return @bitCast(i32, float);
}

pub fn __eqdf2(a: f64, b: f64) callconv(.C) i32 {
    return __ledf2(a, b);
}

pub fn __ltdf2(a: f64, b: f64) callconv(.C) i32 {
    return __ledf2(a, b);
}

pub fn __nedf2(a: f64, b: f64) callconv(.C) i32 {
    return __ledf2(a, b);
}

pub fn __gtdf2(a: f64, b: f64) callconv(.C) i32 {
    return __gedf2(a, b);
}

// Comparison between f80

pub inline fn cmp_f80(comptime RT: type, a: f80, b: f80) RT {
    const a_rep = @ptrCast(*const std.math.F80Repr, &a).*;
    const b_rep = @ptrCast(*const std.math.F80Repr, &b).*;
    const sig_bits = std.math.floatMantissaBits(f80);
    const int_bit = 0x8000000000000000;
    const sign_bit = 0x8000;
    const special_exp = 0x7FFF;

    // If either a or b is NaN, they are unordered.
    if ((a_rep.exp & special_exp == special_exp and a_rep.fraction ^ int_bit != 0) or
        (b_rep.exp & special_exp == special_exp and b_rep.fraction ^ int_bit != 0))
        return RT.Unordered;

    // If a and b are both zeros, they are equal.
    if ((a_rep.fraction | b_rep.fraction) | ((a_rep.exp | b_rep.exp) & special_exp) == 0)
        return .Equal;

    if (@boolToInt(a_rep.exp == b_rep.exp) & @boolToInt(a_rep.fraction == b_rep.fraction) != 0) {
        return .Equal;
    } else if (a_rep.exp & sign_bit != b_rep.exp & sign_bit) {
        // signs are different
        if (@bitCast(i16, a_rep.exp) < @bitCast(i16, b_rep.exp)) {
            return .Less;
        } else {
            return .Greater;
        }
    } else {
        const a_fraction = a_rep.fraction | (@as(u80, a_rep.exp) << sig_bits);
        const b_fraction = b_rep.fraction | (@as(u80, b_rep.exp) << sig_bits);
        if (a_fraction < b_fraction) {
            return .Less;
        } else {
            return .Greater;
        }
    }
}

pub fn __lexf2(a: f80, b: f80) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);
    const float = cmp_f80(LE, a, b);
    return @bitCast(i32, float);
}

pub fn __gexf2(a: f80, b: f80) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);
    const float = cmp_f80(GE, a, b);
    return @bitCast(i32, float);
}

pub fn __eqxf2(a: f80, b: f80) callconv(.C) i32 {
    return __lexf2(a, b);
}

pub fn __ltxf2(a: f80, b: f80) callconv(.C) i32 {
    return __lexf2(a, b);
}

pub fn __nexf2(a: f80, b: f80) callconv(.C) i32 {
    return __lexf2(a, b);
}

pub fn __gtxf2(a: f80, b: f80) callconv(.C) i32 {
    return __gexf2(a, b);
}

// Comparison between f128

pub fn __letf2(a: f128, b: f128) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);
    const float = cmp(f128, LE, a, b);
    return @bitCast(i32, float);
}

pub fn __getf2(a: f128, b: f128) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);
    const float = cmp(f128, GE, a, b);
    return @bitCast(i32, float);
}

pub fn __eqtf2(a: f128, b: f128) callconv(.C) i32 {
    return __letf2(a, b);
}

pub fn __lttf2(a: f128, b: f128) callconv(.C) i32 {
    return __letf2(a, b);
}

pub fn __netf2(a: f128, b: f128) callconv(.C) i32 {
    return __letf2(a, b);
}

pub fn __gttf2(a: f128, b: f128) callconv(.C) i32 {
    return __getf2(a, b);
}

// Unordered comparison between f32/f64/f128

pub fn __unordsf2(a: f32, b: f32) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);
    return unordcmp(f32, a, b);
}

pub fn __unorddf2(a: f64, b: f64) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);
    return unordcmp(f64, a, b);
}

pub fn __unordtf2(a: f128, b: f128) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);
    return unordcmp(f128, a, b);
}

// ARM EABI intrinsics

pub fn __aeabi_fcmpeq(a: f32, b: f32) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, __eqsf2, .{ a, b }) == 0);
}

pub fn __aeabi_fcmplt(a: f32, b: f32) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, __ltsf2, .{ a, b }) < 0);
}

pub fn __aeabi_fcmple(a: f32, b: f32) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, __lesf2, .{ a, b }) <= 0);
}

pub fn __aeabi_fcmpge(a: f32, b: f32) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, __gesf2, .{ a, b }) >= 0);
}

pub fn __aeabi_fcmpgt(a: f32, b: f32) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, __gtsf2, .{ a, b }) > 0);
}

pub fn __aeabi_fcmpun(a: f32, b: f32) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __unordsf2, .{ a, b });
}

pub fn __aeabi_dcmpeq(a: f64, b: f64) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, __eqdf2, .{ a, b }) == 0);
}

pub fn __aeabi_dcmplt(a: f64, b: f64) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, __ltdf2, .{ a, b }) < 0);
}

pub fn __aeabi_dcmple(a: f64, b: f64) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, __ledf2, .{ a, b }) <= 0);
}

pub fn __aeabi_dcmpge(a: f64, b: f64) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, __gedf2, .{ a, b }) >= 0);
}

pub fn __aeabi_dcmpgt(a: f64, b: f64) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, __gtdf2, .{ a, b }) > 0);
}

pub fn __aeabi_dcmpun(a: f64, b: f64) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __unorddf2, .{ a, b });
}

test "comparesf2" {
    _ = @import("comparesf2_test.zig");
}
test "comparedf2" {
    _ = @import("comparedf2_test.zig");
}
