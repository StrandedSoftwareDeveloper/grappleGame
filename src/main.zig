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
const POINT_BAR_WIDTH: f32 = 10.0;
const POINT_BAR_COLOR: u32 = 0x22CCCC00;

const Camera = struct {
    pos: vec.Vector2f,
    zoom: f32, // Does nothing for now
};

const InputEvent = struct {
    frame: usize,
    x: c_int,
    y: c_int,
    button: c_int,
    bDown: c_int,
};

var camera: Camera = .{.pos = .zero(), .zoom = 1.0};
var screen_aabb: AABB = .{.min = .zero(), .max = .zero()};
var do_grapple: bool = false;
//var grapple_target: vec.Vector2f = .zero();
var wrap_points: [100]vec.Vector2f = undefined; // Index 0 is the point closest to the player
var num_wrap_points: usize = 0;
var rope_len: f32 = 0.0;
var player_pos: vec.Vector2f = .zero();
var pull_in: bool = false;
var just_released: bool = false;
var world_boxes: [20]AABB = undefined;
var frameNum: usize = 0;
var input_sequence: std.ArrayList(InputEvent) = undefined;
var global_allocator: std.mem.Allocator = undefined;

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
    
    pub fn raycast(aabb: AABB, orig: vec.Vector2f, dir: vec.Vector2f) ?vec.Vector2f {
        var out: ?vec.Vector2f = null;
        
        const slope: f32 = dir.y / dir.x;
        const inv_slope: f32 = dir.x / dir.y;
            
        const rise1: f32 = aabb.min.y - orig.y;
        const run1: f32 = rise1 / slope;
        var hit1: ?vec.Vector2f = .{ .x = run1 + orig.x, .y = aabb.min.y };
        if (hit1.?.x < aabb.min.x or hit1.?.x > aabb.max.x) {
            hit1 = null;
        }
        
        const rise2: f32 = aabb.max.y - orig.y;
        const run2: f32 = rise2 / slope;
        var hit2: ?vec.Vector2f = .{ .x = run2 + orig.x, .y = aabb.max.y };
        if (hit2.?.x < aabb.min.x or hit2.?.x > aabb.max.x) {
            hit2 = null;
        }
        
        
        const rise3: f32 = aabb.min.x - orig.x;
        const run3: f32 = rise3 / inv_slope;
        var hit3: ?vec.Vector2f = .{ .x = aabb.min.x, .y = run3 + orig.y };
        if (hit3.?.y < aabb.min.y or hit3.?.y > aabb.max.y) {
            hit3 = null;
        }
        
        const rise4: f32 = aabb.max.x - orig.x;
        const run4: f32 = rise4 / inv_slope;
        var hit4: ?vec.Vector2f = .{ .x = aabb.max.x, .y = run4 + orig.y };
        if (hit4.?.y < aabb.min.y or hit4.?.y > aabb.max.y) {
            hit4 = null;
        }
        
        const hit1_dist: f32 = if (hit1) |h| h.subtract(orig).length() else std.math.inf(f32);
        const hit2_dist: f32 = if (hit2) |h| h.subtract(orig).length() else std.math.inf(f32);
        const hit3_dist: f32 = if (hit3) |h| h.subtract(orig).length() else std.math.inf(f32);
        const hit4_dist: f32 = if (hit4) |h| h.subtract(orig).length() else std.math.inf(f32);
        
        if (hit1_dist < hit2_dist and hit1_dist < hit3_dist and hit1_dist < hit4_dist) {
            out = hit1;
        } else if (hit2_dist < hit1_dist and hit2_dist < hit3_dist and hit2_dist < hit4_dist) {
            out = hit2;
        } else if (hit3_dist < hit1_dist and hit3_dist < hit2_dist and hit3_dist < hit4_dist) {
            out = hit3;
        } else {
            out = hit4;
        }
        
        if (out) |o| {
            if (orig.subtract(o).normalize().dot(dir) < 0.0) {
                return null;
            }
        }
        
        return out;
    }
    
    pub fn draw(aabb: AABB, cam: Camera) void {
        const cam_space_aabb: AABB = .{.min = aabb.min.subtract(cam.pos), .max = aabb.max.subtract(cam.pos)};
        
        if (!screen_aabb.pointInside(cam_space_aabb.min) and !screen_aabb.pointInside(cam_space_aabb.max)) {
            //return; // Yes, I know this will erroneously cancel when `screen_aabb` is entirely inside `cam_space_aabb`
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

fn raycastWorld(boxes: []AABB, orig: vec.Vector2f, dir: vec.Vector2f, hit_box_index: *usize) ?vec.Vector2f {
    var closestHit: ?vec.Vector2f = null;
    
    for (0.., boxes) |i, box| {
        const result: ?vec.Vector2f = box.raycast(orig, dir);
        if (result) |r| {
            if (closestHit) |ch| {
                if (r.subtract(orig).length() < ch.subtract(orig).length()) {
                    hit_box_index.* = i;
                    closestHit = r;
                }
            } else {
                hit_box_index.* = i;
                closestHit = r;
            }
        }
    }
    
    return closestHit;
}

//`x` and `y` are in screen-space pixels
fn castGrapple(x: c_int, y: c_int) void {
    var target: vec.Vector2f = .zero();
    target.x = @floatFromInt(x);
    target.y = @floatFromInt(y);
    target = target.add(camera.pos);
    
    var hit_box_index: usize = 0;
    const result: ?vec.Vector2f = raycastWorld(&world_boxes, player_pos, player_pos.subtract(target).normalize(), &hit_box_index);
    if (result) |r| {
        target = r;
        
        wrap_points[0] = target;
        num_wrap_points = 1;
        
        rope_len = player_pos.subtract(wrap_points[0]).length();
        do_grapple = true;
        pull_in = true;
    }
}

export fn HandleKey(keycode: c_int, bDown: c_int) void {
    _ = bDown;
    _ = keycode;
}

export fn HandleButton(x: c_int, y: c_int, button: c_int, bDown: c_int) void {
    std.debug.print("#{}:{} {} {} {}\n", .{frameNum, x, y, button, bDown});
    input_sequence.append(global_allocator, .{.frame = frameNum, .x = x, .y = y, .button = button, .bDown = bDown}) catch unreachable;
    if (bDown == 1) {
        if (button == 1) {
            if (!do_grapple) {
                castGrapple(x, y);
            } else {
                pull_in = true;
            }
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
    global_allocator = allocator;
    
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    
    const stdout = &stdout_writer.interface;
    
    
    const slice: []u8 = try std.Io.Dir.cwd().readFileAlloc(init.io, "inputs.zon", allocator, .unlimited);
    defer allocator.free(slice);
    
    const sliceZ: [:0]u8 = try allocator.dupeSentinel(u8, slice, 0);
    defer allocator.free(sliceZ);
    
    const inputs: []InputEvent = try std.zon.parse.fromSliceAlloc([]InputEvent, allocator, sliceZ, null, .{});
    defer std.zon.parse.free(allocator, inputs);
    
    std.debug.print("len:{}\n", .{inputs.len});
    
    
    input_sequence = try std.ArrayList(InputEvent).initCapacity(allocator, 1);
    defer input_sequence.deinit(allocator);
    
    _ = c.CNFGSetup("Grapple Game", width, height);
    screen_aabb.max.x = @floatFromInt(width);
    screen_aabb.max.y = @floatFromInt(height);
    
    var pcg: std.Random.Pcg = std.Random.Pcg.init(2);
    const rng: std.Random = pcg.random();
    
    var point_bars: [world_boxes.len]AABB = undefined;
    
    for (0..world_boxes.len) |i| {
        world_boxes[i].min = .{.x = rng.float(f32) * (screen_aabb.max.x - BOX_SIZE.x), .y = rng.float(f32) * (screen_aabb.max.y - BOX_SIZE.y)};
        world_boxes[i].max = world_boxes[i].min.add(BOX_SIZE);
    }
    
    world_boxes[0].min.x = -1000.0; // Bottom wall
    world_boxes[0].min.y = 990.0;
    world_boxes[0].max.x = 1000.0;
    world_boxes[0].max.y = 1000.0;
    
    world_boxes[1].min.x = 990.0; // Right wall
    world_boxes[1].min.y = -1000.0;
    world_boxes[1].max.x = 1000.0;
    world_boxes[1].max.y = 1000.0;
    
    world_boxes[2].min.x = -1000.0; // Top wall
    world_boxes[2].min.y = -1000.0;
    world_boxes[2].max.x = 1000.0;
    world_boxes[2].max.y = -990.0;
    
    world_boxes[3].min.x = -1000.0; // Left wall
    world_boxes[3].min.y = -1000.0;
    world_boxes[3].max.x = -990.0;
    world_boxes[3].max.y = 1000.0;
    
    for (0..point_bars.len) |i| {
        const box_width: f32 = world_boxes[i].max.x - world_boxes[i].min.x;
        const margin: f32 = (box_width / 2.0) - POINT_BAR_WIDTH * 0.5;
        point_bars[i].min = .{ .x = world_boxes[i].min.x + margin, .y = world_boxes[i].min.y - 50.0 };
        point_bars[i].max = .{ .x = world_boxes[i].max.x - margin, .y = world_boxes[i].min.y };
    }
    
    var score: u32 = 0;
    
    player_pos = .{ .x = screen_aabb.max.x * 0.5, .y = screen_aabb.max.y * 0.5 };
    var player_vel: vec.Vector2f = .{ .x = 0.0, .y = 0.0 };
    
    rope_len = player_pos.subtract(wrap_points[0]).length();
    
    var input_index: usize = 0;
    
    var last_pos: vec.Vector2f = player_pos;
    var lastTime: std.Io.Timestamp = std.Io.Clock.real.now(init.io);
    while (c.CNFGHandleInput() != 0) {
        if (inputs.len > 0 and input_index < inputs.len) {
            const i: InputEvent = inputs[input_index];
            if (i.frame <= frameNum) {
                HandleButton(i.x, i.y, i.button, i.bDown);
                input_index += 1;
            }
        }
        
        c.CNFGClearFrame();
        c.CNFGGetDimensions(&width, &height);
        screen_aabb.max.x = @floatFromInt(width);
        screen_aabb.max.y = @floatFromInt(height);
        
        const dt: f32 = 1.0/60.0;
        
        // Integrator
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
        
        // Unwrap logic
        if (do_grapple and num_wrap_points > 1) {
            var hit_box_index: usize = 0;
            const result: ?vec.Vector2f = raycastWorld(&world_boxes, player_pos, player_pos.subtract(wrap_points[1]).normalize(), &hit_box_index);
            //_ = c.CNFGColor(0x77777700);
            //drawCircleWorld(camera, player_pos, 10.0);
            //_ = c.CNFGColor(0x77777700);
            //drawCircleWorld(camera, player_pos.subtract(wrap_points[1]).normalize().multScalar(-10.0).add(player_pos), 10.0);
            const is_straight: bool = wrap_points[0].subtract(player_pos).normalize().dot(wrap_points[1].subtract(player_pos).normalize()) > 0.99;
            if ((result == null or player_pos.subtract(result.?).length() > player_pos.subtract(wrap_points[1]).length() - 20.0) and is_straight) { // Unwrap
                _ = c.CNFGColor(0xFFFFFF00);
                drawLineWorld(camera, player_pos, wrap_points[1]);
                //std.debug.print("b\n", .{});
                for (0..num_wrap_points-1) |i| {
                    //_ = i;
                    wrap_points[i] = wrap_points[i + 1];
                }
                num_wrap_points -= 1;
                rope_len = player_pos.subtract(wrap_points[0]).length();
            } else {
                _ = c.CNFGColor(0xFF000000);
                //drawLineWorld(camera, player_pos, result orelse wrap_points[1]);
            }
        }
        
        // Wrap logic
        if (do_grapple) {
            var hit_box_index: usize = 0;
            const result: ?vec.Vector2f = raycastWorld(&world_boxes, player_pos, player_pos.subtract(wrap_points[0]).normalize(), &hit_box_index);
            if (result) |r| {
                if (player_pos.subtract(r).length() < @min(player_pos.subtract(wrap_points[0]).length(), rope_len) - 10.0) {
                    //std.debug.print("a {d:.2}, {d:.2}\n", .{player_pos.subtract(r).length(), rope_len});
                    const hit_box: AABB = world_boxes[hit_box_index];
                    var new_wrap_point: vec.Vector2f = .zero();
                    new_wrap_point.x = if (@abs(r.x - hit_box.min.x) < @abs(r.x - hit_box.max.x)) hit_box.min.x else hit_box.max.x;
                    new_wrap_point.y = if (@abs(r.y - hit_box.min.y) < @abs(r.y - hit_box.max.y)) hit_box.min.y else hit_box.max.y;
                    
                    _ = c.CNFGColor(0xFFFF0000);
                    drawLineWorld(camera, player_pos, new_wrap_point);
                    num_wrap_points = @min(num_wrap_points + 1, wrap_points.len);
                    var i: usize = num_wrap_points - 1;
                    while (i > 0) : (i -= 1) {
                        //std.debug.print("{}\n", .{i});
                        wrap_points[i] = wrap_points[i - 1];
                    }
                    wrap_points[0] = new_wrap_point;
                    rope_len = player_pos.subtract(wrap_points[0]).length();
                }
            }
        }
        
        //std.debug.print("{}\n", .{ num_wrap_points });
        
        // Rope physics
        if (do_grapple) {
            if (pull_in and rope_len > 50.0 * dt) {
                rope_len -= 50.0 * dt;
                //const dir: vec.Vector2f = player_pos.subtract(grapple_target).normalize();
                //player_vel = player_vel.add(dir.multScalar(-1.0));
            }
            
            const target_dist: f32 = player_pos.subtract(wrap_points[0]).length();
            //std.debug.print("{d:.2} {d:.2}\n", .{target_dist, rope_len});
            if (target_dist > rope_len or false) {
                const dir: vec.Vector2f = player_pos.subtract(wrap_points[0]).normalize();
                const vel_to_redirect: f32 = @max(player_vel.dot(dir), 0.0);
                player_vel = player_vel.subtract(dir.multScalar(vel_to_redirect)); // TODO: Take this removed energy and apply it tangent to the rope
                player_pos = player_pos.subtract(dir.multScalar(target_dist - rope_len));
            }
        }
        
        // Collision physics
        var colliding: bool = false;
        var cp: vec.Vector2f = .zero();
        for (world_boxes) |box| {
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
        
        for (0..point_bars.len) |i| {
            if (point_bars[i].SDF(player_pos) <= PLAYER_RAD) {
                score += 1;
                point_bars[i].min = .zero();
                point_bars[i].max = .zero();
            }
        }
        
        camera.pos = player_pos.subtract(.{ .x = screen_aabb.max.x * 0.5, .y = screen_aabb.max.y * 0.5 });
        
        
        
        _ = c.CNFGColor(ROPE_COLOR);
        if (do_grapple) {
            drawLineWorld(camera, wrap_points[0], player_pos);
            for (0..num_wrap_points-1) |i| {
                drawLineWorld(camera, wrap_points[i], wrap_points[i+1]);
            }
        }
        
        _ = c.CNFGColor(BOX_COLOR);
        for (world_boxes) |box| {
            box.draw(camera);
        }
        
        _ = c.CNFGColor(POINT_BAR_COLOR);
        for (point_bars) |bar| {
            bar.draw(camera);
        }
        
        _ = c.CNFGColor(PLAYER_COLOR);
        drawCircleWorld(camera, player_pos, PLAYER_RAD);
        
        if (colliding) {
            _ = c.CNFGColor(0x0000FF00);
            //drawCircleWorld(camera, cp, 4.0);
        }
        
        _ = c.CNFGColor(0xFFFFFF00);
        c.CNFGPenX = 10;
        c.CNFGPenY = 10;
        var score_text_buffer: [32]u8 = undefined;
        const text: [:0]const u8 = try std.fmt.bufPrintSentinel(&score_text_buffer, "Score: {}", .{ score }, 0);
        c.CNFGDrawText(text, 8);
        
        c.CNFGSwapBuffers();
        const now: std.Io.Timestamp = std.Io.Clock.real.now(init.io);
        if (lastTime.durationTo(now).nanoseconds < 16_666_666) {
            try std.Io.sleep(init.io, std.Io.Duration.fromNanoseconds(16_666_666 - lastTime.durationTo(now).nanoseconds), std.Io.Clock.real);
        }
        lastTime = now;
        frameNum += 1;
    }
    
    try std.zon.stringify.serialize(input_sequence.items, .{}, stdout);
    
    try stdout.flush();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
