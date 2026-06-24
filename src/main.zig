const std = @import("std");
const vec = @import("vector.zig");
const c = @import("c");

// export var CNFGPenX: c_int = 0;
// export var CNFGPenY: c_int = 0;
// export var CNFGBGColor: u32 = 0;
// export var CNFGLastColor: u32 = 0;
// export var CNFGDialogColor: u32 = 0;

const BOX_SIZE: vec.Vector2f = .{.x = 50, .y = 50};
const BOX_COLOR: u32 = 0x77777700;
const PLAYER_COLOR: u32 = 0xFF000000;
const PLAYER_RAD: f32 = 5.0;
const ROPE_COLOR: u32 = 0x00FF0000;

const Camera = struct {
    pos: vec.Vector2f,
    zoom: f32, // Does nothing for now
};

var camera: Camera = .{.pos = .zero(), .zoom = 1.0};
var screen_aabb: AABB = .{.min = .zero(), .max = .zero()};
var do_grapple: bool = false;
var grapple_target: vec.Vector2f = .zero();
var rope_len: f32 = 0.0;
var player_pos: vec.Vector2f = .zero();
var pull_in: bool = false;
var just_released: bool = false;

const AABB = struct {
    min: vec.Vector2f,
    max: vec.Vector2f,
    
    pub fn pointInside(aabb: AABB, pos: vec.Vector2f) bool {
        return pos.x > aabb.min.x and pos.y > aabb.min.y and pos.x < aabb.max.x and pos.y < aabb.max.y;
    }
    
    // Adapted from https://iquilezles.org/articles/distfunctions2d/ by Inigo Quilez, MIT license
    pub fn SDF(aabb: AABB, pos: vec.Vector2f) f32 {
        const center: vec.Vector2f = aabb.max.subtract(aabb.min).multScalar(0.5).add(aabb.min);
        const p: vec.Vector2f = pos.subtract(center);
        const b: vec.Vector2f = aabb.max.subtract(aabb.min).multScalar(0.5);
        const d: vec.Vector2f = p.abs().subtract(b);
        return vec.Vector2f.length(vec.Vector2f.max(d, .zero())) + @min(@max(d.x,d.y),0.0);
    }
    
    pub fn closestPoint(aabb: AABB, pos: vec.Vector2f) vec.Vector2f {
        var out: vec.Vector2f = undefined;
        out.x = std.math.clamp(pos.x, aabb.min.x, aabb.max.x);
        out.y = std.math.clamp(pos.y, aabb.min.y, aabb.max.y);
        if (aabb.pointInside(pos)) {
            const xDist: f32 = @min(@abs(pos.x-aabb.min.x), @abs(pos.x-aabb.max.x));
            const yDist: f32 = @min(@abs(pos.y-aabb.min.y), @abs(pos.y-aabb.max.y));
            if (xDist < yDist) {
                out.x = if (@abs(pos.x-aabb.min.x) < @abs(pos.x-aabb.max.x)) aabb.min.x else aabb.max.x;
            } else {
                out.y = if (@abs(pos.y-aabb.min.y) < @abs(pos.y-aabb.max.y)) aabb.min.y else aabb.max.y;
            }
        }
        return out;
    }
    
    pub fn draw(aabb: AABB, cam: Camera) void {
        const cam_space_aabb: AABB = .{.min = aabb.min.subtract(cam.pos), .max = aabb.max.subtract(cam.pos)};
        
        if (!screen_aabb.pointInside(cam_space_aabb.min) and !screen_aabb.pointInside(cam_space_aabb.max)) {
            return; // Yes, I know this will erroneously cancel when `screen_aabb` is entirely inside `cam_space_aabb`
        }
        
        const x1: c_short = @intFromFloat(cam_space_aabb.min.x);
        const y1: c_short = @intFromFloat(cam_space_aabb.min.y);
        const x2: c_short = @intFromFloat(cam_space_aabb.max.x);
        const y2: c_short = @intFromFloat(cam_space_aabb.max.y);
        
        c.CNFGTackRectangle(x1, y1, x2, y2);
        //c.CNFGDrawBox(x1, y1, x2, y2);
    }
};

var mouseX: i32 = 0;
var mouseY: i32 = 0;

var width: c_short = 800;
var height: c_short = 600;

fn drawCircle(x: c_short, y: c_short, r: f32) void {
    var circle: [16]c.RDPoint = undefined;
    for (0..16) |i| {
        const angle: f32 = (std.math.degreesToRadians(360.0) / 16.0) * @as(f32, @floatFromInt(i));
        //std.debug.print("{d:.2}\n", .{angle});
        circle[i].x = @as(c_short, @intFromFloat(std.math.cos(angle)*r)) + x;
        circle[i].y = @as(c_short, @intFromFloat(std.math.sin(angle)*r)) + y;
    }
    c.CNFGTackPoly(@ptrCast(&circle), circle.len);
}

fn drawCircleWorld(cam: Camera, pos: vec.Vector2f, r: f32) void {
    const pos_cam_space: vec.Vector2f = pos.subtract(cam.pos);
    
    if (!screen_aabb.pointInside(pos_cam_space)) {
        return;
    }
    
    const x: c_short = @intFromFloat(pos_cam_space.x);
    const y: c_short = @intFromFloat(pos_cam_space.y);
    drawCircle(x, y, r);
}

fn drawLineWorld(cam: Camera, a: vec.Vector2f, b: vec.Vector2f) void {
    const a_cam_space: vec.Vector2f = a.subtract(cam.pos);
    const b_cam_space: vec.Vector2f = b.subtract(cam.pos);
    
    if (!screen_aabb.pointInside(a_cam_space) and !screen_aabb.pointInside(b_cam_space)) {
        return;
    }
    
    const x1: c_short = @intFromFloat(a_cam_space.x);
    const y1: c_short = @intFromFloat(a_cam_space.y);
    const x2: c_short = @intFromFloat(b_cam_space.x);
    const y2: c_short = @intFromFloat(b_cam_space.y);
    c.CNFGTackSegment(x1, y1, x2, y2);
}

export fn HandleKey(keycode: c_int, bDown: c_int) void {
    _ = bDown;
    _ = keycode;
}

export fn HandleButton(x: c_int, y: c_int, button: c_int, bDown: c_int) void {
    //std.debug.print("{} {}\n", .{button, bDown});
     if (bDown == 1) {
         if (button == 1) {
             do_grapple = true;
             pull_in = true;
             grapple_target.x = @floatFromInt(x);
             grapple_target.y = @floatFromInt(y);
             grapple_target = grapple_target.add(camera.pos);
             rope_len = player_pos.subtract(grapple_target).length();
         } else if (button == 3) {
             do_grapple = false;
        }
     } else if (bDown == 0) {
         if (button == 1) {
             pull_in = false;
        }
    }
}

export fn HandleMotion(x: c_int, y: c_int, mask: c_int) void {
    _ = mask;
    mouseX = x;
    mouseY = y;
}
export fn HandleDestroy() void {}

//All coordinates are in the same space
fn inAABB(x: i32, y: i32, min_x: i32, min_y: i32, max_x: i32, max_y: i32) bool {
    return x >= min_x and x <= max_x and y >= min_y and y <= max_y;
}

pub fn main(init: std.process.Init) !void {
    const allocator: std.mem.Allocator = init.gpa;
    _ = allocator;

    _ = c.CNFGSetup("Grapple Game", width, height);
    screen_aabb.max.x = @floatFromInt(width);
    screen_aabb.max.y = @floatFromInt(height);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    
    var pcg: std.Random.Pcg = std.Random.Pcg.init(2);
    const rng: std.Random = pcg.random();
    
    
    var boxes: [20]AABB = undefined;
    for (0..boxes.len) |i| {
        boxes[i].min = .{.x = rng.float(f32) * (screen_aabb.max.x - BOX_SIZE.x), .y = rng.float(f32) * (screen_aabb.max.y - BOX_SIZE.y)};
        boxes[i].max = boxes[i].min.add(BOX_SIZE);
    }
    
    player_pos = .{ .x = screen_aabb.max.x * 0.5, .y = screen_aabb.max.y * 0.5 };
    var player_vel: vec.Vector2f = .{ .x = 0.0, .y = 0.0 };
    
    rope_len = player_pos.subtract(grapple_target).length();

    var last_pos: vec.Vector2f = player_pos;
    var lastTime: std.Io.Timestamp = std.Io.Clock.real.now(init.io);
    var frameNum: usize = 0;
    while (c.CNFGHandleInput() != 0) {
        c.CNFGClearFrame();
        c.CNFGGetDimensions(&width, &height);
        screen_aabb.max.x = @floatFromInt(width);
        screen_aabb.max.y = @floatFromInt(height);
        
        const dt: f32 = 1.0/60.0;
        
        const player_acc: vec.Vector2f = .{ .x = 0.0, .y = 50.0 };
        player_vel = player_pos.subtract(last_pos).divideScalar(dt);
        last_pos = player_pos;
        player_vel = player_vel.add(player_acc.multScalar(dt));
        player_pos = player_pos.add(player_vel.multScalar(dt));
        
//         if (pull_in) {
//             //do_grapple = true;
//             pull_in = true;
//             grapple_target.x = @floatFromInt(mouseX);
//             grapple_target.y = @floatFromInt(mouseY);
//             grapple_target = grapple_target.add(camera.pos);
//             //rope_len = player_pos.subtract(grapple_target).length();
//         }
        
        if (do_grapple) {
            if (pull_in and rope_len > 50.0 * dt) {
                rope_len -= 50.0 * dt;
                //const dir: vec.Vector2f = player_pos.subtract(grapple_target).normalize();
                //player_vel = player_vel.add(dir.multScalar(-1.0));
            }
            
            const target_dist: f32 = player_pos.subtract(grapple_target).length();
            //std.debug.print("{d:.2} {d:.2}\n", .{target_dist, rope_len});
            if (target_dist > rope_len or false) {
                const dir: vec.Vector2f = player_pos.subtract(grapple_target).normalize();
                const vel_to_redirect: f32 = @max(player_vel.dot(dir), 0.0);
                player_vel = player_vel.subtract(dir.multScalar(vel_to_redirect)); // TODO: Take this removed energy and apply it tangent to the rope
                player_pos = player_pos.subtract(dir.multScalar(target_dist - rope_len));
            }
        }
        
        var colliding: bool = false;
        var cp: vec.Vector2f = .zero();
        for (boxes) |box| {
            const sdf: f32 = box.SDF(player_pos);
            if (sdf < PLAYER_RAD) {
                //const cp: vec.Vector2f = box.closestPoint(player_pos);
                cp = box.closestPoint(player_pos);
                
                //_ = c.CNFGColor(0x0000FF00);
                //drawCircleWorld(camera, cp, 4.0);
                
                const dir: vec.Vector2f = player_pos.subtract(cp).normalize();
                player_vel = player_vel.subtract(dir.multScalar(player_vel.dot(dir)));
                //player_pos = player_pos.subtract(dir.multScalar(sdf - PLAYER_RAD));
                if (sdf < 0.0) {
                    player_pos = cp.subtract(dir.multScalar(PLAYER_RAD));
                } else {
                    player_pos = cp.add(dir.multScalar(PLAYER_RAD));
                }
                colliding = true;
            }
        }
        
        camera.pos = player_pos.subtract(.{ .x = screen_aabb.max.x * 0.5, .y = screen_aabb.max.y * 0.5 });
        
        
        
        _ = c.CNFGColor(ROPE_COLOR);
        if (do_grapple) {
            drawLineWorld(camera, grapple_target, player_pos);
        }
        
        _ = c.CNFGColor(BOX_COLOR);
        for (boxes) |box| {
            box.draw(camera);
        }
        
        _ = c.CNFGColor(PLAYER_COLOR);
        drawCircleWorld(camera, player_pos, PLAYER_RAD);
        
        if (colliding) {
            _ = c.CNFGColor(0x0000FF00);
            //drawCircleWorld(camera, cp, 4.0);
        }

        c.CNFGSwapBuffers();
        const now: std.Io.Timestamp = std.Io.Clock.real.now(init.io);
        if (lastTime.durationTo(now).nanoseconds < 16_666_666) {
            try std.Io.sleep(init.io, std.Io.Duration.fromNanoseconds(16_666_666 - lastTime.durationTo(now).nanoseconds), std.Io.Clock.real);
        }
        lastTime = now;
        frameNum += 1;
    }

    try stdout.flush();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
