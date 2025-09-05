# Dwit - SmartZigFileSystem

# Engineering Learning Journal 📚

> **Goal:** Build a smart file manager in Zig while documenting the entire learning journey  

## ...

Building an intelligent file organizer that will eventually help with office document management - finding companies in contracts, analyzing invoices, visualizing document relationships. But first, we need solid foundations.

> As an intern I've seen how this office/.pdfs tasks can be boring or labourius in terms of taking much time for small reward. 


---

## 📖 Learning Log

### Day 1 - September 5, 2025
**Current Status:** Have Zig basics from Ziglings, ready to tackle real project

**Today's Hypothesis:**
> "Starting with file system operations will give me the best foundation for this project"

**What I need to learn:**
1. **File System Operations** (Priority 1)
   - Directory traversal in Zig
   - File metadata extraction
   - Error handling for file operations

2. **CLI Design** (Priority 2)
   - Argument parsing patterns
   - User-friendly help systems

3. **Data Management** (Priority 3)
   - Memory management for file lists
   - Efficient data structures

**Learning Plan:**

Week 1: File Operations & Basic CLI
Week 2: Data Structures & Memory Management  
Week 3: Configuration & Error Handling
Week 4: Integration & Testing


**Questions to explore:**
- How does Zig handle large directory trees?
- What's the best pattern for CLI commands in Zig?
- How to handle permissions errors gracefully?

---

## 🏗️ Architecture Evolution

### Phase 1: MVP Smart File Manager
```
dwit scan ./documents          # Scan directory
dwit list --type=pdf          # Filter by type
dwit search "contract"        # Simple text search
dwit move *.pdf ./contracts   # Organize files
```

**Core Components:**
```
src/
├── core/
│   ├── file_scanner.zig     # Directory traversal
│   ├── file_info.zig        # Metadata extraction
│   └── file_operations.zig  # Move, copy, delete
├── cli/
│   ├── commands.zig         # Command dispatch
│   └── args.zig             # Argument parsing
├── config/
│   └── config.zig           # Configuration system
└── main.zig                 # Entry point
```

### Phase 2: Document Intelligence (Future)
- OCR integration for scanned documents
- Entity extraction (company names, NIPs, amounts)
- Document relationship graphs
- Business intelligence features

---

## 🧪 Experiments & Hypotheses

### Experiment 1: Directory Scanning Performance
**Hypothesis:** Using `std.fs.Dir.iterate()` will be faster than recursive function calls for large directories

**Test Plan:**
1. Create test directory with 10k files
2. Implement both approaches
3. Benchmark performance
4. Measure memory usage

**Expected Outcome:** Iterator should be more memory-efficient

### Experiment 2: CLI User Experience
**Hypothesis:** Users prefer contextual help over man pages for file operations

**Test Plan:**
1. Implement `zfm help <command>` pattern
2. Add examples to each command
3. Test with colleagues
4. Gather feedback

---

## 💡 Design Decisions

### Decision 1: Error Handling Strategy
**Problem:** How to handle file permission errors gracefully?

**Options:**
1. Fail fast - stop on first error
2. Skip and continue - log errors but keep going
3. Interactive - ask user what to do

**Decision:** Skip and continue (Option 2)  
**Reasoning:** Real-world directories often have permission issues. Better to process what we can and report issues at the end.

```zig
// Pattern to implement:
fn scanDirectory(path: []const u8) !ScanResult {
    var result = ScanResult.init();
    var errors = std.ArrayList(FileError).init(allocator);
    
    // Process files, collect errors
    for (files) |file| {
        processFile(file) catch |err| {
            try errors.append(FileError{ .path = file, .error = err });
            continue; // Keep going
        };
    }
    
    result.errors = errors.toOwnedSlice();
    return result;
}
```

### Decision 2: Configuration Format
**Problem:** JSON vs TOML vs custom format?

**Decision:** JSON (for now)  
**Reasoning:** Zig has built-in JSON support, simpler to start with. Can migrate to TOML later if needed.

---

## 🎓 Learning Notes

### Zig File System Patterns

**Directory Iteration Pattern:**
```zig
var dir = try std.fs.openDirAbsolute(path, .{ .iterate = true });
defer dir.close();

var iterator = dir.iterate();
while (try iterator.next()) |entry| {
    switch (entry.kind) {
        .directory => {
            // Recursive call or add to queue
        },
        .file => {
            // Process file
            const file_info = try getFileInfo(entry.name);
        },
        else => continue, // Skip symlinks, etc.
    }
}
```

**Key Insights:**
- Always defer `dir.close()`
- Handle errors at each level
- Use `entry.kind` to filter file types

### Memory Management Lessons

**Pattern 1: Owned vs Borrowed Strings**
```zig
// BAD: Dangling pointer
fn getFileName(path: []const u8) []const u8 {
    return std.fs.path.basename(path); // Points to input string
}

// GOOD: Owned copy
fn getFileName(allocator: Allocator, path: []const u8) ![]const u8 {
    return allocator.dupe(u8, std.fs.path.basename(path));
}
```

---

## 🔄 Weekly Retrospectives

### Phase1 Retrospective
**Goals:**
- [ ] Basic directory scanning
- [ ] File metadata extraction
- [ ] Simple CLI interface

---

## 🚀 Current Status

**Completed:**
- [x] Project planning and architecture design
- [x] Learning roadmap creation

**In Progress:**
- [ ] Setting up development environment
- [ ] Implementing basic file scanner

**Next Steps:**
1. Create basic project structure
2. Implement directory traversal
3. Add file metadata extraction
4. Build simple CLI interface

---

## 🤔 Open Questions

1. **Performance:** How does Zig file I/O compare to Rust/Go for large directories?
2. **Cross-platform:** What Windows-specific issues should I expect?
3. **Memory:** What's the best pattern for handling large file lists?
4. **Testing:** How to create reproducible test environments for file operations?

---

## 📚 Resources & References

**Zig Documentation:**
- [std.fs](https://ziglang.org/documentation/master/std/#std.fs)
- [std.process](https://ziglang.org/documentation/master/std/#std.process)
- [std.ArrayList](https://ziglang.org/documentation/master/std/#std.ArrayList)

**Inspiration Projects:**
- [zig-clap](https://github.com/Hejsil/zig-clap) - CLI argument parsing
- [zls](https://github.com/zigtools/zls) - Large Zig project structure
- [uv](https://github.com/astral-sh/uv) - Modern CLI tool design

**Learning Materials:**
- Ziglings exercises (completed ✓ mostly)
- Zig Language Docs (www.zigland.com)
- "Zig in 100seconds" I just Love this guy



## 🎯 Success Metrics

**Short-term (1 month):**
- [ ] Can scan 10k+ files without crashing
- [ ] CLI feels intuitive to use
- [ ] Code is well-structured and documented

**Medium-term (3 months):**
- [ ] Handles edge cases gracefully
- [ ] Performance competitive with existing tools
- [ ] Ready for OCR/document analysis features

**Long-term (6 months):**
- [ ] Used daily for document management
- [ ] Can analyze business documents
- [ ] Visualize document relationships

