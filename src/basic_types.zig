const std = @import("std");

pub const Compass = enum(u8) { SW = 0, S, SE, W, CENTER, E, NW, N, NE };

const NW = Dir.init(Compass.NW);
const N = Dir.init(Compass.N);
const NE = Dir.init(Compass.NE);
const SW = Dir.init(Compass.SW);
const S = Dir.init(Compass.S);
const SE = Dir.init(Compass.SE);
const W = Dir.init(Compass.W);
const C = Dir.init(Compass.CENTER);
const E = Dir.init(Compass.E);

const rotations = [_]Dir{
    SW, W,  NW, N,  NE, E,  SE, S,
    S,  SW, W,  NW, N,  NE, E,  SE,
    SE, S,  SW, W,  NW, N,  NE, E,
    W,  NW, N,  NE, E,  SE, S,  SW,
    C,  C,  C,  C,  C,  C,  C,  C,
    E,  SE, S,  SW, W,  NW, N,  NE,
    NW, N,  NE, E,  SE, S,  SW, W,
    N,  NE, E,  SE, S,  SW, W,  NW,
    NE, E,  SE, S,  SW, W,  NW, N,
};

const NormalizedCoords = [_]Coord{
    Coord.init(-1, -1), // SW
    Coord.init(0, -1), // S
    Coord.init(1, -1), // SE
    Coord.init(-1, 0), // W
    Coord.init(0, 0), // CENTER
    Coord.init(1, 0), // E
    Coord.init(-1, 1), // NW
    Coord.init(0, 1), // N
    Coord.init(1, 1), // NE
};

pub const Dir = struct {
    dir9: Compass,

    pub fn init(d: Compass) Dir {
        return Dir{ .dir9 = d };
    }

    fn asU8(self: Dir) u8 {
        return @intFromEnum(self.dir9);
    }

    pub fn rotate(self: Dir, n: isize) Dir {
        return rotations[self.asU8() * 8 + @as(usize, @intCast(n & 7))];
    }

    pub fn rotate90DegCW(self: Dir) Dir {
        return self.rotate(2);
    }

    pub fn rotate90DegCCW(self: Dir) Dir {
        return self.rotate(-2);
    }

    pub fn rotate180Deg(self: Dir) Dir {
        return self.rotate(4);
    }

    pub fn asNormalizedCoord(self: Dir) Coord {
        return NormalizedCoords[self.asU8()];
    }

    pub fn asNormalizedPolar(self: Dir) Polar {
        return Polar{ .mag = 1, .dir = self };
    }
};

test "Dir functions" {
    const dir = Dir.init(Compass.SW);
    try std.testing.expectEqual(@intFromEnum(Compass.SW), dir.rotate(0).asU8());
    try std.testing.expectEqual(@intFromEnum(Compass.NW), dir.rotate90DegCW().asU8());
    try std.testing.expectEqual(@intFromEnum(Compass.SE), dir.rotate90DegCCW().asU8());
    try std.testing.expectEqual(@intFromEnum(Compass.NE), dir.rotate180Deg().asU8());
    try std.testing.expectEqual(Coord.init(-1, -1), dir.asNormalizedCoord());
    try std.testing.expectEqual(Polar.init(1, dir), dir.asNormalizedPolar());
}

const Coord = struct {
    x: i16,
    y: i16,

    pub fn init(x0: i16, y0: i16) Coord {
        return Coord{ .x = x0, .y = y0 };
    }

    pub fn isNormalized(self: Coord) bool {
        return self.x >= -1 and self.x <= 1 and self.y >= -1 and self.y <= 1;
    }

    pub fn length(self: Coord) usize {
        const x: f64 = @floatFromInt(self.x);
        const y: f64 = @floatFromInt(self.y);
        return @intFromFloat(std.math.hypot(x, y));
    }

    pub fn scale(self: *Coord, len: i16) void {
        self.x *= len;
        self.y *= len;
    }

    pub fn normalize(self: Coord) Coord {
        return self.asDir().asNormalizedCoord();
    }

    pub fn asDir(self: Coord) Dir {
        // the closest a pair of int16_t's come to any of these lines is 8e-8 degrees, so the result is exact
        const tanN: u16 = 13860;
        const tanD: u16 = 33461;
        const conversion = [_]Dir{ S, C, SW, N, SE, E, N, N, N, N, W, NW, N, NE, N, N };

        const x: i32 = self.x;
        const y: i32 = self.y;
        const xp: i32 = x * tanD + y * tanN;
        const yp: i32 = y * tanD - x * tanN;

        // We can easily check which side of the four boundary lines
        // the point now falls on, giving 16 cases, though only 9 are
        // possible.
        // return conversion[(yp > 0) * 8 + (xp > 0) * 4 + (yp > xp) * 2 + (yp >= -xp)];

        const yp_0: isize = if (yp > 0) 1 else 0;
        const xp_0: isize = if (xp > 0) 1 else 0;
        const yp_xp: isize = if (yp > xp) 1 else 0;
        const yp_xp2: isize = if (yp >= -xp) 1 else 0;
        const index = yp_0 * 8 + xp_0 * 4 + yp_xp * 2 + yp_xp2;
        //std.debug.print("index = {}\n", .{index});
        return conversion[@intCast(index)];
        //return conversion[yp_0 * 8 + xp_0 * 4 + yp_xp * 2 + yp_xp2];
    }

    pub fn asPolar(self: Coord) Polar {
        return Polar{ .mag = @intCast(self.length()), .dir = self.asDir() };
    }

    // returns -1.0 (opposite directions) .. +1.0 (same direction)
    // returns 1.0 if either vector is (0,0)
    pub fn raySameness(self: Coord, other: Coord) f64 {
        const x: i64 = self.x;
        const y: i64 = self.y;
        const xx: i64 = other.x;
        const yy: i64 = other.y;
        const mag: i64 = (x * x + y * y) * (xx * xx + yy * yy);
        if (mag == 0) {
            return 1.0; // anything is "same" as zero vector
        }

        return if ((x * xx + y * yy) > 0) 1.0 else -1.0;
    }

    // returns -1.0 (opposite directions) .. +1.0 (same direction)
    // returns 1.0 if self is (0,0) or d is CENTER
    pub fn raySamenessWithDir(self: Coord, d: Dir) f64 {
        return self.raySameness(d.asNormalizedCoord());
    }
};

test "Coord functions" {
    const c1 = Coord.init(1, 0);
    const c2 = Coord.init(-3, 4);
    const c3 = Coord.init(-1, 1);
    const p1 = Polar.init(5, Dir.init(Compass.NW));
    try std.testing.expectEqual(true, c1.isNormalized());
    try std.testing.expectEqual(false, c2.isNormalized());
    try std.testing.expectEqual(1, c1.length());
    try std.testing.expectEqual(5, c2.length());
    //std.debug.print("normalize = {}\n", .{c1.normalize()});
    //std.debug.print("normalize = {}\n", .{c2.normalize()});
    //std.debug.print("normalize = {}\n", .{c3.normalize()});
    try std.testing.expectEqual(c3, c2.normalize());
    try std.testing.expectEqual(p1, c2.asPolar());
    try std.testing.expectEqual(-1.0, c2.raySamenessWithDir(SE));
    try std.testing.expectEqual(1.0, c2.raySamenessWithDir(NE));
}

const Polar = struct {
    mag: isize,
    dir: Dir,

    pub fn init(mag: isize, dir: Dir) Polar {
        return Polar{ .mag = mag, .dir = dir };
    }

    pub fn asCoord(self: Polar) Coord {
        const mag = self.mag;
        const dir = self.dir;

        // (Thanks to @Asa-Hopkins for this optimized function -- drm)

        // 3037000500 is 1/sqrt(2) in 32.32 fixed point
        const coordMags = [9]i64{
            3037000500, // SW
            1 << 32, // S
            3037000500, // SE
            1 << 32, // W
            0, // CENTER
            1 << 32, // E
            3037000500, // NW
            1 << 32, // N
            3037000500, // NE
        };

        var len: i64 = coordMags[dir.asU8()] * mag;

        // We need correct rounding, the idea here is to add/sub 1/2 (in fixed point)
        // and truncate. We extend the sign of the magnitude with a cast,
        // then shift those bits into the lower half, giving 0 for mag >= 0 and
        // -1 for mag<0. An XOR with this copies the sign onto 1/2, to be exact
        // we'd then also subtract it, but we don't need to be that precise.

        const temp: i64 = (@as(i64, mag) >> 32) ^ ((1 << 31) - 1);
        len = @divTrunc((len + temp), (1 << 32));

        //return NormalizedCoords[dir.asU8()].scale(@intCast(len));
        var coord = NormalizedCoords[dir.asU8()];
        _ = coord.scale(@intCast(len));
        return coord;
    }
};

test "Polar functions" {
    const p1 = Polar.init(5, Dir.init(Compass.NW));
    const c1 = Coord.init(-4, 4);
    try std.testing.expectEqual(c1, p1.asCoord());
}
