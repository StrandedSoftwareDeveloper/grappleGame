const std = @import("std");

pub const Vector4 = struct {
    w: f64,
    x: f64,
    y: f64,
    z: f64,

    pub fn length(self: Vector4) f64 {
        return std.math.sqrt(self.length2());
    }

    pub fn length2(self: Vector4) f64 {
        return self.w * self.w + self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn lerp(min: Vector4, max: Vector4, k: Vector4) Vector4 {
        return .{ .w = std.math.lerp(min.w, max.w, k.w), .x = std.math.lerp(min.x, max.x, k.x), .y = std.math.lerp(min.y, max.y, k.y), .z = std.math.lerp(min.z, max.z, k.z) };
    }

    pub fn multScalar(self: Vector4, scalar: f64) Vector4 {
        return .{ .w = self.w * scalar, .x = self.x * scalar, .y = self.y * scalar, .z = self.z * scalar };
    }

    pub fn divideScalar(self: Vector4, scalar: f64) Vector4 {
        return .{ .w = self.w / scalar, .x = self.x / scalar, .y = self.y / scalar, .z = self.z / scalar };
    }

    pub fn normalize(self: Vector4) Vector4 {
        return self.divideScalar(self.length());
    }

    pub fn add(a: Vector4, b: Vector4) Vector4 {
        return .{ .w = a.w + b.w, .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn sub(a: Vector4, b: Vector4) Vector4 {
        return .{ .w = a.w - b.w, .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    //4D vectors apparently don't have cross products
    pub fn cross(a: Vector4, b: Vector4) Vector4 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn dot(a: Vector4, b: Vector4) f64 {
        return a.w * b.w + a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn zero() Vector4 {
        return .{ .w = 0.0, .x = 0.0, .y = 0.0, .z = 0.0 };
    }

    //Note: Takes `actual` and `expected` are swapped from std.testing.expectEqual()!
    pub fn expectEqual(actual: Vector4, expected: Vector4, tolerance: f64) !void {
        try std.testing.expectApproxEqAbs(expected.w, actual.w, tolerance);
        try std.testing.expectApproxEqAbs(expected.x, actual.x, tolerance);
        try std.testing.expectApproxEqAbs(expected.y, actual.y, tolerance);
        try std.testing.expectApproxEqAbs(expected.z, actual.z, tolerance);
    }
};

pub const Vector3f = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn length(self: Vector3f) f32 {
        return std.math.sqrt(self.length2());
    }

    pub fn length2(self: Vector3f) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn lerp(min: Vector3f, max: Vector3f, k: Vector3f) Vector3f {
        return .{ .x = std.math.lerp(min.x, max.x, k.x), .y = std.math.lerp(min.y, max.y, k.y), .z = std.math.lerp(min.z, max.z, k.z) };
    }

    pub fn multScalar(self: Vector3f, scalar: f32) Vector3f {
        return .{ .x = self.x * scalar, .y = self.y * scalar, .z = self.z * scalar };
    }

    pub fn divideScalar(self: Vector3f, scalar: f32) Vector3f {
        return .{ .x = self.x / scalar, .y = self.y / scalar, .z = self.z / scalar };
    }

    pub fn normalize(self: Vector3f) Vector3f {
        return self.divideScalar(self.length());
    }

    pub fn add(a: Vector3f, b: Vector3f) Vector3f {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn sub(a: Vector3f, b: Vector3f) Vector3f {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn cross(a: Vector3f, b: Vector3f) Vector3f {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn dot(a: Vector3f, b: Vector3f) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn zero() Vector3f {
        return .{ .x = 0.0, .y = 0.0, .z = 0.0 };
    }
    
    //Note: Takes `actual` and `expected` are swapped from std.testing.expectEqual()!
    pub fn expectEqual(actual: Vector3f, expected: Vector3f, tolerance: f32) !void {
        try std.testing.expectApproxEqAbs(expected.x, actual.x, tolerance);
        try std.testing.expectApproxEqAbs(expected.y, actual.y, tolerance);
        try std.testing.expectApproxEqAbs(expected.z, actual.z, tolerance);
    }
};

pub const Vector3d = struct {
    x: f64,
    y: f64,
    z: f64,

    pub fn length(self: Vector3d) f64 {
        return std.math.sqrt(self.length2());
    }

    pub fn length2(self: Vector3d) f64 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn lerp(min: Vector3d, max: Vector3d, k: Vector3d) Vector3d {
        return .{ .x = std.math.lerp(min.x, max.x, k.x), .y = std.math.lerp(min.y, max.y, k.y), .z = std.math.lerp(min.z, max.z, k.z) };
    }

    pub fn multScalar(self: Vector3d, scalar: f64) Vector3d {
        return .{ .x = self.x * scalar, .y = self.y * scalar, .z = self.z * scalar };
    }

    pub fn divideScalar(self: Vector3d, scalar: f64) Vector3d {
        return .{ .x = self.x / scalar, .y = self.y / scalar, .z = self.z / scalar };
    }

    pub fn normalize(self: Vector3d) Vector3d {
        return self.divideScalar(self.length());
    }

    pub fn add(a: Vector3d, b: Vector3d) Vector3d {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn sub(a: Vector3d, b: Vector3d) Vector3d {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn cross(a: Vector3d, b: Vector3d) Vector3d {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn dot(a: Vector3d, b: Vector3d) f64 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn zero() Vector3d {
        return .{ .x = 0.0, .y = 0.0, .z = 0.0 };
    }
    
    //Note: Takes `actual` and `expected` are swapped from std.testing.expectEqual()!
    pub fn expectEqual(actual: Vector3d, expected: Vector3d, tolerance: f64) !void {
        try std.testing.expectApproxEqAbs(expected.x, actual.x, tolerance);
        try std.testing.expectApproxEqAbs(expected.y, actual.y, tolerance);
        try std.testing.expectApproxEqAbs(expected.z, actual.z, tolerance);
    }
};

pub const Vector2f = struct {
    x: f32,
    y: f32,

    pub fn length(self: Vector2f) f32 {
        return std.math.sqrt(self.length2());
    }

    pub fn length2(self: Vector2f) f32 {
        return self.x * self.x + self.y * self.y;
    }

    pub fn lerp(min: Vector2f, maximum: Vector2f, k: Vector2f) Vector2f {
        return .{ .x = std.math.lerp(min.x, maximum.x, k.x), .y = std.math.lerp(min.y, maximum.y, k.y) };
    }

    pub fn divideScalar(self: *const Vector2f, scalar: f32) Vector2f {
        return .{ .x = self.x / scalar, .y = self.y / scalar };
    }

    pub fn multScalar(self: *const Vector2f, scalar: f32) Vector2f {
        return .{ .x = self.x * scalar, .y = self.y * scalar };
    }

    pub fn max(a: Vector2f, b: Vector2f) Vector2f {
        return .{ .x = @max(a.x, b.x), .y = @max(a.y, b.y) };
    }

    pub fn addScalar(self: *const Vector2f, scalar: f32) Vector2f {
        return .{ .x = self.x + scalar, .y = self.y + scalar };
    }

    pub fn getAngle(self: *const Vector2f) f64 {
        return std.math.atan2(self.y, self.x);
    }

    pub fn rotate(self: *const Vector2f, angle: f64) Vector2f {
        const startAngle: f64 = self.getAngle();
        const len: f32 = self.length();
        return .{ .x = std.math.cos(startAngle + angle) * len, .y = std.math.sin(startAngle + angle) * len };
    }

    pub fn dot(a: Vector2f, b: Vector2f) f32 {
        return a.x * b.x + a.y * b.y;
    }

    pub fn add(a: Vector2f, b: Vector2f) Vector2f {
        return .{ .x = a.x + b.x, .y = a.y + b.y };
    }

    pub fn subtract(a: Vector2f, b: Vector2f) Vector2f {
        return .{ .x = a.x - b.x, .y = a.y - b.y };
    }
    
    pub fn zero() Vector2f {
        return .{ .x = 0.0, .y = 0.0 };
    }
    
    pub fn normalize(self: Vector2f) Vector2f {
        return self.divideScalar(self.length());
    }
    
    pub fn abs(self: Vector2f) Vector2f {
        return .{ .x = @abs(self.x), .y = @abs(self.y) };
    }
};

pub const Vector2d = struct {
    x: f64,
    y: f64,

    pub fn length(self: Vector2d) f64 {
        return std.math.sqrt(self.length2());
    }

    pub fn length2(self: Vector2d) f64 {
        return self.x * self.x + self.y * self.y;
    }

    pub fn lerp(min: Vector2d, maximum: Vector2d, k: Vector2d) Vector2d {
        return .{ .x = std.math.lerp(min.x, maximum.x, k.x), .y = std.math.lerp(min.y, maximum.y, k.y) };
    }

    pub fn divideScalar(self: *const Vector2d, scalar: f64) Vector2d {
        return .{ .x = self.x / scalar, .y = self.y / scalar };
    }

    pub fn multScalar(self: *const Vector2d, scalar: f64) Vector2d {
        return .{ .x = self.x * scalar, .y = self.y * scalar };
    }

    pub fn max(a: Vector2d, b: Vector2d) Vector2d {
        return .{ .x = @max(a.x, b.x), .y = @max(a.y, b.y) };
    }

    pub fn addScalar(self: *const Vector2d, scalar: f64) Vector2d {
        return .{ .x = self.x + scalar, .y = self.y + scalar };
    }

    pub fn getAngle(self: *const Vector2d) f64 {
        return std.math.atan2(self.y, self.x);
    }

    pub fn rotate(self: *const Vector2d, angle: f64) Vector2d {
        const startAngle: f64 = self.getAngle();
        const len: f64 = self.length();
        return .{ .x = std.math.cos(startAngle + angle) * len, .y = std.math.sin(startAngle + angle) * len };
    }

    pub fn dot(a: Vector2d, b: Vector2d) f64 {
        return a.x * b.x + a.y * b.y;
    }

    pub fn add(a: Vector2d, b: Vector2d) Vector2d {
        return .{ .x = a.x + b.x, .y = a.y + b.y };
    }

    pub fn subtract(a: Vector2d, b: Vector2d) Vector2d {
        return .{ .x = a.x - b.x, .y = a.y - b.y };
    }
    
    pub fn zero() Vector2d {
        return .{ .x = 0.0, .y = 0.0 };
    }
    
    pub fn normalize(self: Vector2d) Vector2d {
        return self.divideScalar(self.length());
    }
};
