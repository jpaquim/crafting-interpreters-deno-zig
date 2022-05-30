const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn ALLOCATE(allocator: Allocator, comptime T: type, count: usize) []T {
    return std.mem.bytesAsSlice(T, reallocate(
        allocator,
        null,
        0,
        @sizeOf(T) * count,
    ).?);
}

pub fn GROW_CAPACITY(capacity: usize) usize {
    return if (capacity < 8) 8 else capacity * 2;
}

pub fn GROW_ARRAY(allocator: Allocator, comptime T: type, slice: ?[]T, old_count: usize, new_count: usize) ?[]T {
    return std.mem.bytesAsSlice(T, @alignCast(@alignOf(T), reallocate(
        allocator,
        if (slice != null) std.mem.sliceAsBytes(slice.?) else null,
        @sizeOf(T) * old_count,
        @sizeOf(T) * new_count,
    ).?));
}

pub fn FREE_ARRAY(allocator: Allocator, comptime T: type, slice: ?[]T, old_count: usize) void {
    const result = reallocate(
        allocator,
        if (slice != null) std.mem.sliceAsBytes(slice.?) else null,
        @sizeOf(T) * old_count,
        0,
    );
    std.debug.assert(result == null);
}

pub fn reallocate(allocator: Allocator, slice: ?[]u8, old_size: usize, new_size: usize) ?[]u8 {
    if (new_size == 0) {
        if (slice != null) allocator.free(slice.?);
        return null;
    }

    if (old_size == 0) {
        return allocator.alloc(u8, new_size) catch std.process.exit(1);
    }

    const result = allocator.realloc(slice.?, new_size) catch std.process.exit(1);
    return result;
}
