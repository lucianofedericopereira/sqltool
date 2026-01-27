<p align="center">
  <img src="assets/logo.svg" alt="sqltool logo" width="400">
</p>

# sqltool

Local MySQL/MariaDB instance manager for development. No containers, no systemd services - just isolated database instances that run when you need them.

## Features

- **No containers** - runs mysqld directly as your user
- **Isolated instances** - each project gets its own data directory, socket, port, and logs
- **No auto-start** - databases only run when you start them
- **Multi-distro support** - auto-detects your distro and installs MariaDB if needed
- **Simple workflow** - add, start, stop, backup, restore, clone

## Requirements

- Perl 5 (pre-installed on most systems)
- MariaDB or MySQL (auto-installed if missing)

## Installation

### macOS (Homebrew)

```bash
brew tap lucianofedericopereira/sqltool
brew install sqltool
```

### Linux

```bash
git clone https://github.com/lucianofedericopereira/sqltool.git
cd sqltool
chmod +x sqltool
sudo cp sqltool /usr/local/bin/
```

Or just run it from anywhere:

```bash
./sqltool help
```

## Quick Demo

Run the included demo script to see sqltool in action:

```bash
./tryme.sh
```

This will:
1. Create a test instance called `demo`
2. Start it
3. Create a sample table with data
4. Make a backup
5. Stop the instance

After the demo, clean up with `./sqltool remove demo`.

## Usage

```bash
# Create a new database instance
sqltool add myproject

# Start it
sqltool start myproject

# Connect
mysql -u myproject -p -S ~/sql/myproject/data/mysql.sock
# or via TCP
mysql -u myproject -p -h 127.0.0.1 -P 3307

# Stop when done
sqltool stop myproject

# See all instances
sqltool list
```

## Commands

| Command | Description |
|---------|-------------|
| `add <project>` | Create new database instance |
| `remove <project>` | Delete instance and all data |
| `start <project>` | Start instance |
| `stop <project>` | Stop instance |
| `list` | List all instances |
| `info <project>` | Show instance details |
| `port <project>` | Show port number |
| `logs <project>` | Show recent error logs |
| `backup <project>` | Create SQL backup |
| `restore <project> <file.sql>` | Restore from backup |
| `clone <src> <dst>` | Clone an instance |
| `status <project>` | Quick status check |
| `help` | Show help |

## Directory Structure

All data is stored in `~/sql/`:

```
~/sql/
├── myproject/
│   ├── data/          # MySQL data files
│   │   └── mysql.sock # Unix socket
│   ├── etc/
│   │   └── my.cnf     # Instance config
│   ├── logs/
│   │   └── error.log  # Error log
│   └── scripts/
│       ├── start      # Start script
│       └── stop       # Stop script
├── anotherproject/
│   └── ...
└── backups/           # SQL backups
```

## Supported Systems

Auto-detection and installation works on:

- **macOS**: via Homebrew (Apple Silicon and Intel)
- **Debian/Ubuntu** family: Debian, Ubuntu, Linux Mint, Pop!_OS, elementary OS
- **Red Hat** family: Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux
- **Arch** family: Arch Linux, Manjaro
- **SUSE** family: openSUSE, SUSE
- **Others**: Void Linux, Alpine Linux

For other systems, install MariaDB manually first.

## Why Perl?

Perl is the right tool for this job:

- **Pre-installed everywhere** - available on virtually every GNU/Linux system out of the box, from Debian to Arch to Alpine
- **No setup required** - no `pip install`, no `npm install`, no `cargo build`, no virtual environments, no dependency hell
- **Uses only core modules** - File::Path, File::Basename, POSIX are part of Perl's standard library since forever
- **Single file distribution** - copy one file, make it executable, done
- **Battle-tested stability** - Perl scripts written 20 years ago still run today without modification
- **Fast startup** - instant execution, no JIT warm-up, no interpreter initialization overhead
- **Excellent for system tasks** - process management, file operations, and text processing are Perl's bread and butter

### The Unix tradition

Perl follows the Unix philosophy that shaped GNU/Linux: small, focused tools that do one thing well. Like `grep`, `awk`, and `sed` before it, Perl was designed for text processing and system administration - the same tasks this tool performs.

Classic sysadmin tools have always been scripts:
- `autoconf`, `automake` - Perl and shell
- `git-send-email` - Perl
- `debhelper` - Perl
- Countless system utilities in `/usr/bin` - Perl, shell, awk

This isn't legacy - it's proven engineering. These tools have managed millions of servers for decades. Perl is part of the GNU/Linux ecosystem in a way that newer languages simply aren't.

### Why this matters today

In 2026, installing a simple CLI tool often means:
- Python: create venv, pip install dependencies, hope nothing conflicts with system Python
- Node: npm install, node_modules bloat, version conflicts
- Rust/Go: compile step, or trust pre-built binaries

With Perl:
```bash
chmod +x sqltool
./sqltool add myproject
```

That's it. Works on a fresh Debian install. Works on a minimal Alpine container. Works on your colleague's Fedora laptop. No `pyproject.toml`, no `package.json`, no build artifacts.

For a CLI tool that manages system processes and files, Perl hits the sweet spot between shell scripts (too limited for complex logic) and heavier languages (unnecessary complexity for this use case).

## Default Credentials

Each instance creates:

- **Database**: `<project>`
- **User**: `<project>`
- **Password**: `admin1234`
- **Port**: 3307 (increments for each new instance)

### Security Note

The default password `admin1234` is meant for **local development only**. These instances bind to `127.0.0.1` by default and are not accessible from the network.

If you need to change the password or create additional users, connect as root:

```bash
mysql -u root -S ~/sql/myproject/data/mysql.sock
```

Then run:
```sql
ALTER USER 'myproject'@'localhost' IDENTIFIED BY 'your_secure_password';
FLUSH PRIVILEGES;
```

**Never expose these instances to the network without proper security configuration.**

## License

LGPL-2.1 - See source file for details.

## Author

Luciano Federico Pereira <lucianopereira@posteo.es>
