# Dwit - SmartZigFileSystem
`dwit` is a file management and knowledge-base tool.
It scans files, identifies them by their content hash,
and allows you to create relationships (tags and links) between them.

```bash
⏱️  Benchmark: Scanned 447181 files in 5029 ms

```


### BUILDING FROM SOURCE

```bash
git clone https://www.github.com/kitajusSus/DWIT.git
cd DWIT
zig build -Doptimize=ReleaseFast
sudo cp zig-out/bin/dwit /usr/local/bin/


dwit <command> [options]
dwit tag <file_path> <tag1> [tag2] ...
dwit scan <directory_path>
dwit list [--type <extension>]
dwit link <source_file> <target_file>
dwit find --tag <tag_name>
```

**Working on on project commands**
```bash
# if you are testing if from source add `zig build --` before every commands
# (forgot `dwit`)

#for cleaning you db
rm dwit.db 2>/dev/null
# When running from the source directory
zig build run -- <command> [options]
zig build run -- scan .
zig build run -- list --type pdf



## if you use arch install needed package
sudo pacman -Syu graphviz
zig build run -- export-graph > graph.dot
# and use graphviz on it
dot -Tpng graph.dot -o graph.png



```


-----

<details>
<summary>Commands Details</summary>



## Commands

### `scan`

Scans a directory and builds/updates the file database.

```bash
dwit scan <directory_path>
```

**Description:**
Recursively scans the given directory (e.g., `.`). It hashes every file found and saves its hash and path to the `dwit.db` database.

The scanner automatically ignores common cache/VCS directories, such as:

  * `.git`
  * `.zig-cache`
  * `zig-out`
  * `node_modules`

Upon completion, it prints a summary of the total files scanned and the time taken.

-----

### `list`

Lists all files known to the database.

```bash
dwit list [--type <extension>]
```

**Description:**
Prints a list of all file paths stored in `dwit.db`.

**Options:**

  * `--type <extension>`: (Optional) Filters the list to show only files with the specified extension (e.g., `pdf` or `.pdf`).

-----

### `tag`

Adds one or more tags to a file.

```bash
dwit tag <file_path> <tag1> [tag2] ...
```

**Description:**
Associates one or more string tags with the file specified by `<file_path>`. The file must already exist in the database (run `scan` first).

-----

### `link`

Creates a directed link between two files.

```bash
dwit link <source_file> <target_file>
```

**Description:**
Creates a directional relationship *from* the `<source_file>` *to* the `<target_file>`. Both files must be known to the database.

-----

### `info`

Displays detailed information about a single file.

```bash
dwit info <file_path>
```

**Description:**
Provides a complete summary for the specified file, including:

  * The file's unique content hash.
  * A list of all tags associated with the file.
  * A list of all links, showing both outgoing (`->`) and incoming (`<-`) relationships.

-----

### `find`

Finds all files associated with a specific tag.

```bash
dwit find --tag <tag_name>
```

**Description:**
Searches the database and prints a list of all files that have been marked with the specified `<tag_name>`.

-----

### `export-graph`

Exports the entire database structure as a `.dot` graph.

```bash
dwit export-graph
```

**Description:**
Prints a graph definition in the DOT language (for use with Graphviz) to standard output. In this graph:

  * **Nodes** are the unique file hashes.
  * **Node Labels** are the human-readable file paths.
  * **Edges** represent the links created with the `link` command.

**Example (Visualizing the graph):**

```bash
# 1. Export the graph to a file
dwit export-graph > my_graph.dot

# 2. Use Graphviz (dot) to render it as an image
dot -Tpng my_graph.dot -o my_graph.png
```


</details>


# Engineering
> **Goal:** Build a smart file manager in Zig
## ...

Building an intelligent file organizer that will eventually help with office document management -
finding companies in contracts, analyzing invoices, visualizing document relationships.

> As an intern I've seen how this office/.pdfs tasks can be boring or labourius in terms of taking much time for small reward.


---

## 📖 Learning Log

**Current Status:** Have Zig basics from Ziglings, ready to tackle real project

> "Starting with file system operations will give me the best foundation for this project"

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




**Questions to explore:**
- How does Zig handle large directory trees?
- What's the best pattern for CLI commands in Zig?
- How to handle permissions errors gracefully?

**How to create custom config for every user?**
Config it's needed to create struct of slices for skiping the scans:

- defaults
- reading json?
- creating .gitignore?
- adding full scan with this ignored_dirs
- adding -b for benchmark and check how does it perform, if Does not get worse leave it
-
---

## 🏗️ Architecture Evolution
Tests:

```bash
# clean old database if exists
rm dwit.db 2>/dev/null

# create test files
echo "note about ZIG" > note.txt
echo "PDF FILE ABOUT SKIBIDI TOILET" > memo.pdf
mkdir -p projects
echo "README" > projects/readme.md
```





### Phase 1: MVP Smart File Manager
- [x] already did commands

```
dwit scan ./documents          # Scan directory
dwit list --type=pdf          # Filter by type
dwit list    # show every file from database
dwit search "contract"        # Simple text search
```

**Core Components:**
```
src/
├── core/
│   ├── database.zig
│   ├── hashing.zig
│   └── types.zig
├── main.zig                 # Entry point

├── lib.zig
```

### Phase 2: Document Intelligence (Future)
- [ ] now trying to do phase 2
- [ ] OCR integration for scanned documents
- [ ] Entity extraction (company names, NIPs, amounts)
- [ ] Document relationship graphs
- [ ] Business intelligence features

### Phase 3: Better Bigger Stronger

- [ ] shows only file names and not path
- [ ] makes auto-tags based on config
- [ ] works on explorer/web



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

### Decision 3: Performance Optimization Strategies

#### 1. Multithreading
- [ ] Looking for info

Instead of processing files sequentially (one by one), utilize a thread pool
(e.g., 4 or 8 threads). This allows the application to perform tasks in parallel.

For example, while one thread is blocked waiting for a disk read (I/O-bound),
another thread can be actively processing data in the CPU (CPU-bound), and a third
can be writing metadata to the database. This parallel execution is the most important
optimization for this type of mixed I/O and CPU workload, ensuring that
system resources are used efficiently.

#### 2. Asynchronous I/O (Async I/O)
- [ ]  Looking for info

Async I/O is a more advanced paradigm that complements multithreading.
It allows your program to initiate many operations at once without waiting for each one to finish.

Instead of a thread blocking (idling) while waiting for a file read,
the program can "request" the operating system to read 100 files simultaneously.

The program is then free to perform other work. As each file read is completed,
the operating system notifies the program, which can then process the ready data.
This model prevents threads from being wasted on waiting and is highly effective at maximizing throughput,
especially with fast storage devices (SSDs).




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
        },
        .file => {
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
- [x] Implementing basic file scanner

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
- Ziglings exercises (completed ✓ )
- Zig Language Docs (www.zigland.com)
- "Zig in 100seconds" I just Love this guy



## 🎯 Success Metrics

**Short-term (1 month):**
- [x] Can scan 10k+ files without crashing
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

