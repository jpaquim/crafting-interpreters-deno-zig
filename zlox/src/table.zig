const std = @import("std");
const Allocator = std.mem.Allocator;

const memory = @import("./memory.zig");
const ALLOCATE = memory.ALLOCATE;
const FREE_ARRAY = memory.FREE_ARRAY;
const GROW_CAPACITY = memory.GROW_CAPACITY;
const markObject = memory.markObject;
const markValue = memory.markValue;

const o = @import("./object.zig");
const Obj = o.Obj;
const ObjString = o.ObjString;

const v = @import("./value.zig");
const Value = v.Value;
const BOOL_VAL = v.BOOL_VAL;
const IS_NIL = v.IS_NIL;
const NIL_VAL = v.NIL_VAL;

const Entry = struct {
    key: ?*ObjString,
    value: Value,
};

pub const Table = struct {
    count: usize,
    capacity: usize,
    entries: ?[*]Entry,
};

const TABLE_MAX_LOAD = 0.75;

pub fn initTable(table: *Table) void {
    table.count = 0;
    table.capacity = 0;
    table.entries = null;
}

pub fn freeTable(allocator: Allocator, table: *Table) void {
    if (table.entries) |table_entries| {
        FREE_ARRAY(allocator, Entry, table_entries[0..table.capacity], table.capacity);
    }
    initTable(table);
}

fn findEntry(entries: [*]Entry, capacity: usize, key: *ObjString) *Entry {
    var index = key.hash & @intCast(u32, capacity - 1);
    var tombstone: ?*Entry = null;
    while (true) : (index = (index + 1) & @intCast(u32, capacity - 1)) {
        const entry = &entries[index];
        if (entry.key == null) {
            if (IS_NIL(entry.value)) {
                return if (tombstone != null) tombstone.? else entry;
            } else {
                if (tombstone == null) tombstone = entry;
            }
        } else if (entry.key == key) {
            return entry;
        }
    }
}

fn adjustCapacity(allocator: Allocator, table: *Table, capacity: usize) void {
    const entries = ALLOCATE(allocator, Entry, capacity).?;
    for (entries[0..capacity]) |*entry| {
        entry.key = null;
        entry.value = NIL_VAL;
    }

    table.count = 0;
    if (table.entries) |table_entries| {
        for (table_entries[0..table.capacity]) |entry| {
            if (entry.key == null) continue;

            const dest = findEntry(entries.ptr, capacity, entry.key.?);
            dest.key = entry.key;
            dest.value = entry.value;
            table.count += 1;
        }
        FREE_ARRAY(allocator, Entry, table_entries[0..table.capacity], table.capacity);
    }

    table.entries = entries.ptr;
    table.capacity = capacity;
}

pub fn tableGet(table: *Table, key: *ObjString, value: *Value) bool {
    if (table.count == 0) return false;

    const entry = findEntry(table.entries.?, table.capacity, key);
    if (entry.key == null) return false;

    value.* = entry.value;
    return true;
}

pub fn tableSet(allocator: Allocator, table: *Table, key: *ObjString, value: Value) bool {
    if (table.count + 1 > @floatToInt(usize, @intToFloat(f64, table.capacity) * TABLE_MAX_LOAD)) {
        const capacity = GROW_CAPACITY(table.capacity);
        adjustCapacity(allocator, table, capacity);
    }

    const entry = findEntry(table.entries.?, table.capacity, key);
    const is_new_key = entry.key == null;
    if (is_new_key and IS_NIL(entry.value)) table.count += 1;

    entry.key = key;
    entry.value = value;
    return is_new_key;
}

pub fn tableDelete(table: *Table, key: *ObjString) bool {
    if (table.count == 0) return false;

    const entry = findEntry(table.entries.?, table.capacity, key);
    if (entry.key == null) return false;

    entry.key = null;
    entry.value = BOOL_VAL(true);
    return true;
}

pub fn tableAddAll(allocator: Allocator, from: *Table, to: *Table) void {
    var i: usize = 0;
    while (i < from.capacity) : (i += 1) {
        const entry = &from.entries.?[i];
        if (entry.key) |key| {
            _ = tableSet(allocator, to, key, entry.value);
        }
    }
}

pub fn tableFindString(table: *Table, chars: [*]const u8, length: usize, hash: u32) ?*ObjString {
    if (table.count == 0) return null;

    var index = hash & @intCast(u32, table.capacity - 1);
    while (true) : (index = (index + 1) & @intCast(u32, table.capacity - 1)) {
        const entry = &table.entries.?[index];
        if (entry.key) |key| {
            if (key.length == length and key.hash == hash and std.mem.eql(u8, key.chars[0..key.length], chars[0..length])) {
                return key;
            }
        } else {
            if (IS_NIL(entry.value)) return null;
        }
    }
}

pub fn tableRemoveWhite(table: *Table) void {
    _ = table;
    var i: usize = 0;
    while (i < table.capacity) : (i += 1) {
        const entry = &table.entries.?[i];
        if (entry.key != null and !entry.key.?.obj.is_marked) {
            _ = tableDelete(table, entry.key.?);
        }
    }
}

pub fn markTable(allocator: Allocator, table: *Table) void {
    var i: usize = 0;
    while (i < table.capacity) : (i += 1) {
        const entry = &table.entries.?[i];
        markObject(allocator, if (entry.key != null) &entry.key.?.obj else null);
        markValue(allocator, entry.value);
    }
}
