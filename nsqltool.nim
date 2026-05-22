import os, osproc, strutils, strformat, times, posix, tables, streams

const VERSION = "1.0.0"
const MYSQL_PASS = "admin1234"
const PORT_BASE = 3307

let scriptName = getAppFilename().extractFilename()
let BASE = getHomeDir() / "sql"
let BIN = BASE / "bin"
let BACKUPS = BASE / "backups"

var MYSQLD = ""
var MYSQL_CLIENT = ""
var MYSQLADMIN = ""
var MYSQLDUMP = ""
var MYSQL_INSTALL_DB = ""
var IS_MARIADB = false

# --- Helpers ---

proc isSocket(path: string): bool =
  var st: Stat
  if stat(path.cstring, st) == 0:
    return S_ISSOCK(st.st_mode)
  false

proc ensureDirs() =
  createDir(BASE)
  createDir(BIN)
  createDir(BACKUPS)

proc runCmd(cmd: string): bool =
  execCmd(cmd) == 0

proc runBackground(cmd: string) =
  discard execCmd(cmd & " &")

# --- Binary detection ---

proc findBinary(names: seq[string]): string =
  var searchDirs = @[
    "/usr/bin", "/usr/sbin", "/bin", "/sbin",
    "/usr/local/bin", "/usr/local/sbin",
    "/usr/local/mysql/bin", "/opt/mysql/bin", "/opt/mariadb/bin",
  ]
  when defined(macosx):
    searchDirs = @[
      "/opt/homebrew/bin",
      "/opt/homebrew/opt/mariadb/bin",
      "/opt/homebrew/opt/mysql/bin",
      "/usr/local/opt/mariadb/bin",
      "/usr/local/opt/mysql/bin",
    ] & searchDirs

  for name in names:
    let (path, code) = execCmdEx("command -v " & name & " 2>/dev/null")
    if code == 0:
      let p = path.strip()
      if p.len > 0 and fileExists(p):
        return p
    for dir in searchDirs:
      let full = dir / name
      if fileExists(full):
        return full
  ""

proc detectMysqlSystem() =
  MYSQLD         = findBinary(@["mariadbd", "mysqld", "mariadbd-safe", "mysqld_safe"])
  MYSQL_CLIENT   = findBinary(@["mariadb", "mysql"])
  MYSQLADMIN     = findBinary(@["mariadb-admin", "mysqladmin"])
  MYSQLDUMP      = findBinary(@["mariadb-dump", "mysqldump"])
  MYSQL_INSTALL_DB = findBinary(@["mariadb-install-db", "mysql_install_db"])
  if MYSQLD.len > 0:
    let (ver, _) = execCmdEx("'" & MYSQLD & "' --version 2>/dev/null")
    IS_MARIADB = ver.toLowerAscii().contains("mariadb")

proc detectDistro(): string =
  when defined(macosx):
    return "macos"
  if fileExists("/etc/os-release"):
    for line in lines("/etc/os-release"):
      if line.startsWith("ID="):
        return line[3..^1].replace("\"", "")
  "unknown"

proc getInstallCmd(): (string, string) =
  let distro = detectDistro()
  let cmds = {
    "debian":     "sudo apt update && sudo apt install -y mariadb-server mariadb-client",
    "ubuntu":     "sudo apt update && sudo apt install -y mariadb-server mariadb-client",
    "linuxmint":  "sudo apt update && sudo apt install -y mariadb-server mariadb-client",
    "pop":        "sudo apt update && sudo apt install -y mariadb-server mariadb-client",
    "elementary": "sudo apt update && sudo apt install -y mariadb-server mariadb-client",
    "fedora":     "sudo dnf install -y mariadb-server mariadb",
    "rhel":       "sudo dnf install -y mariadb-server mariadb",
    "centos":     "sudo dnf install -y mariadb-server mariadb",
    "rocky":      "sudo dnf install -y mariadb-server mariadb",
    "alma":       "sudo dnf install -y mariadb-server mariadb",
    "arch":       "sudo pacman -S --noconfirm mariadb",
    "manjaro":    "sudo pacman -S --noconfirm mariadb",
    "opensuse":   "sudo zypper install -y mariadb mariadb-client",
    "suse":       "sudo zypper install -y mariadb mariadb-client",
    "void":       "sudo xbps-install -y mariadb",
    "alpine":     "sudo apk add mariadb mariadb-client",
    "macos":      "brew install mariadb",
  }.toTable()
  (distro, cmds.getOrDefault(distro, ""))

proc missingTools(): seq[string] =
  if MYSQLD.len == 0:        result.add("server (mysqld/mariadbd)")
  if MYSQL_CLIENT.len == 0:  result.add("client (mysql/mariadb)")
  if MYSQLADMIN.len == 0:    result.add("admin (mysqladmin/mariadb-admin)")
  if MYSQLDUMP.len == 0:     result.add("dump (mysqldump/mariadb-dump)")

proc detectMysql() =
  detectMysqlSystem()
  if MYSQLD.len == 0 or MYSQL_CLIENT.len == 0 or MYSQLADMIN.len == 0 or MYSQLDUMP.len == 0:
    let missing = missingTools()
    let (distro, installCmd) = getInstallCmd()
    echo "MySQL/MariaDB tools not found."
    echo "Missing: " & missing.join(", ")
    echo "Detected distro: " & distro & "\n"
    if installCmd.len > 0:
      echo "Install MariaDB? [y/N]"
      stdout.write("> ")
      if readLine(stdin).toLowerAscii() == "y":
        echo "Installing MariaDB..."
        if not runCmd(installCmd): quit("Installation failed\n", 1)
        detectMysqlSystem()
      else:
        quit("Cannot continue without MySQL/MariaDB.\n", 1)
    else:
      echo "Unknown distro - please install MariaDB manually:"
      echo "  - macOS:         brew install mariadb"
      echo "  - Debian/Ubuntu: sudo apt install mariadb-server mariadb-client"
      echo "  - Fedora/RHEL:   sudo dnf install mariadb-server mariadb"
      echo "  - Arch:          sudo pacman -S mariadb"
      echo "  - Alpine:        sudo apk add mariadb mariadb-client"
      quit("Cannot continue without MySQL/MariaDB.\n", 1)

  if MYSQLD.len == 0 or MYSQL_CLIENT.len == 0 or MYSQLADMIN.len == 0 or MYSQLDUMP.len == 0:
    echo "\nStill missing after installation: " & missingTools().join(", ")
    echo "Found:"
    echo "  Server:    " & (if MYSQLD.len > 0: MYSQLD else: "(not found)")
    echo "  Client:    " & (if MYSQL_CLIENT.len > 0: MYSQL_CLIENT else: "(not found)")
    echo "  Admin:     " & (if MYSQLADMIN.len > 0: MYSQLADMIN else: "(not found)")
    echo "  Dump:      " & (if MYSQLDUMP.len > 0: MYSQLDUMP else: "(not found)")
    quit("Please check your MariaDB/MySQL installation.\n", 1)

# --- Project helpers ---

proc projectExists(name: string): bool =
  dirExists(BASE / name)

proc assignPort(): int =
  var count = 0
  for kind, path in walkDir(BASE):
    if kind == pcDir:
      let name = path.extractFilename()
      if name != "bin" and name != "backups":
        inc count
  PORT_BASE + count

proc getPort(project: string): string =
  let cfg = BASE / project / "etc" / "my.cnf"
  if not fileExists(cfg): return ""
  for line in lines(cfg):
    if line.startsWith("port"):
      let parts = line.split("=")
      if parts.len >= 2: return parts[1].strip()
  ""

proc isRunning(project: string): bool =
  isSocket(BASE / project / "data" / "mysql.sock")

proc waitForSocket(sockPath: string, timeoutSec = 30): bool =
  for _ in 1..timeoutSec:
    if isSocket(sockPath): return true
    sleep(1000)
  false

proc ensureRunningForOp(project: string): bool =
  if not isRunning(project):
    let dir = BASE / project
    echo "Instance '" & project & "' not running. Starting temporarily..."
    runBackground(dir / "scripts" / "start")
    if not waitForSocket(dir / "data" / "mysql.sock"):
      quit("Timeout waiting for MySQL\n", 1)
    return true
  false

# --- Commands ---

proc printHelp() =
  echo scriptName & " " & VERSION & " - Local MySQL/MariaDB instance manager (no containers)"
  echo ""
  echo "Usage:"
  echo "  " & scriptName & " add <project>       Create new database instance"
  echo "  " & scriptName & " remove <project>    Delete instance and data"
  echo "  " & scriptName & " start <project>     Start instance"
  echo "  " & scriptName & " stop <project>      Stop instance"
  echo "  " & scriptName & " list                List all instances"
  echo "  " & scriptName & " info <project>      Show instance details"
  echo "  " & scriptName & " port <project>      Show port number"
  echo "  " & scriptName & " logs <project>      Show recent logs"
  echo "  " & scriptName & " backup <project>    Backup database"
  echo "  " & scriptName & " restore <project> <file.sql>"
  echo "  " & scriptName & " clone <src> <dst>   Clone instance"
  echo "  " & scriptName & " status <project>    Quick status check"
  echo "  " & scriptName & " debug               Show detected binaries and paths"
  echo "  " & scriptName & " help                Show this help"
  echo "  " & scriptName & " --version           Show version"

proc cmdDebug() =
  detectMysqlSystem()
  let (distro, _) = getInstallCmd()
  let osType = when defined(macosx): "macOS" else: "Linux"
  echo fmt"=== {scriptName} debug info ===\n"
  echo "Version:     " & VERSION
  echo "OS:          " & osType
  echo "Distro:      " & distro
  echo "Base dir:    " & BASE
  echo "Backups dir: " & BACKUPS
  echo "DB Type:     " & (if IS_MARIADB: "MariaDB" else: "MySQL") & "\n"
  echo "Detected binaries:"
  echo "  Server:    " & (if MYSQLD.len > 0: MYSQLD else: "(not found)")
  echo "  Client:    " & (if MYSQL_CLIENT.len > 0: MYSQL_CLIENT else: "(not found)")
  echo "  Admin:     " & (if MYSQLADMIN.len > 0: MYSQLADMIN else: "(not found)")
  echo "  Dump:      " & (if MYSQLDUMP.len > 0: MYSQLDUMP else: "(not found)")
  echo "  InstallDB: " & (if MYSQL_INSTALL_DB.len > 0: MYSQL_INSTALL_DB else: "(not found)") & "\n"
  if MYSQLD.len > 0:
    echo "Server version:"
    stdout.write("  ")
    discard execCmd("'" & MYSQLD & "' --version 2>/dev/null || echo '(could not get version)'")

proc cmdAdd(project: string) =
  if project.len == 0: quit("Usage: " & scriptName & " add <project>\n", 1)
  if projectExists(project): quit("Project '" & project & "' already exists.\n", 1)

  let dir = BASE / project
  let port = assignPort()

  createDir(dir / "data")
  createDir(dir / "etc")
  createDir(dir / "logs")
  createDir(dir / "scripts")

  writeFile(dir / "etc" / "my.cnf", fmt"""# Config compatible with MySQL 5.7+, 8.0+ and MariaDB 10.x, 11.x
[mysqld]
datadir={dir}/data
socket={dir}/data/mysql.sock
pid-file={dir}/data/mysql.pid
port={port}
bind-address=127.0.0.1
log-error={dir}/logs/error.log

# Disable binary logging (not needed for local dev)
skip-log-bin

# Performance settings for local dev
innodb_buffer_pool_size=64M
innodb_log_file_size=16M
max_connections=20

# Disable strict mode for easier development
sql_mode=NO_ENGINE_SUBSTITUTION
""")

  writeFile(dir / "scripts" / "start",
    "#!/bin/sh\nexec " & MYSQLD & " --defaults-file=" & dir & "/etc/my.cnf --user=$(whoami)\n")
  setFilePermissions(dir / "scripts" / "start",
    {fpUserRead, fpUserWrite, fpUserExec, fpGroupRead, fpGroupExec, fpOthersRead, fpOthersExec})

  writeFile(dir / "scripts" / "stop",
    "#!/bin/sh\n" & MYSQLADMIN & " --socket=" & dir & "/data/mysql.sock -u root shutdown 2>/dev/null" &
    " || kill $(cat " & dir & "/data/mysql.pid 2>/dev/null) 2>/dev/null\n")
  setFilePermissions(dir / "scripts" / "stop",
    {fpUserRead, fpUserWrite, fpUserExec, fpGroupRead, fpGroupExec, fpOthersRead, fpOthersExec})

  echo "Initializing database..."
  var initOk = false

  type InitMethod = tuple[cmd, desc: string]
  var initMethods: seq[InitMethod]

  if IS_MARIADB:
    if MYSQL_INSTALL_DB.len > 0:
      initMethods.add((MYSQL_INSTALL_DB & " --datadir='" & dir & "/data' --auth-root-authentication-method=normal",
                       "mariadb-install-db"))
    initMethods.add((MYSQLD & " --initialize-insecure --datadir='" & dir & "/data'",
                     "mysqld --initialize-insecure (fallback)"))
  else:
    initMethods.add((MYSQLD & " --initialize-insecure --datadir='" & dir & "/data' --user=$(whoami)",
                     "mysqld --initialize-insecure"))
    if MYSQL_INSTALL_DB.len > 0:
      initMethods.add((MYSQL_INSTALL_DB & " --datadir='" & dir & "/data'",
                       "mysql_install_db (fallback)"))

  for m in initMethods:
    echo "  Trying: " & m.desc
    if runCmd(m.cmd & " 2>&1"):
      initOk = true
      break

  if not initOk:
    echo "\nAll initialization methods failed."
    echo "Check " & dir & "/logs/error.log for details."
    quit("Database initialization failed\n", 1)

  echo "Starting instance..."
  runBackground(dir / "scripts" / "start")

  if not waitForSocket(dir / "data" / "mysql.sock"):
    quit("Timeout waiting for MySQL to start\n", 1)

  let sql = fmt"""-- Create database
CREATE DATABASE IF NOT EXISTS `{project}`;

-- Create user (compatible with MySQL 5.7+, 8.0+ and MariaDB 10.x, 11.x)
CREATE USER IF NOT EXISTS '{project}'@'localhost' IDENTIFIED BY '{MYSQL_PASS}';
CREATE USER IF NOT EXISTS '{project}'@'127.0.0.1' IDENTIFIED BY '{MYSQL_PASS}';

-- Grant privileges
GRANT ALL PRIVILEGES ON `{project}`.* TO '{project}'@'localhost';
GRANT ALL PRIVILEGES ON `{project}`.* TO '{project}'@'127.0.0.1';
FLUSH PRIVILEGES;
"""

  echo "Setting up database and user..."
  let pipe = startProcess(MYSQL_CLIENT & " --socket='" & dir & "/data/mysql.sock' -u root 2>&1",
                          options = {poUsePath, poEvalCommand})
  pipe.inputStream.write(sql)
  pipe.inputStream.close()
  let sqlOk = pipe.waitForExit() == 0
  pipe.close()

  if not sqlOk:
    echo "Warning: Could not create database/user. You may need to do this manually."

  discard execCmd(dir / "scripts" / "stop")
  sleep(2000)

  echo ""
  echo "Project: " & project
  echo "User:    " & project
  echo "Pass:    " & MYSQL_PASS
  echo "Port:    " & $port
  echo "Socket:  " & dir & "/data/mysql.sock"
  echo "\nConnect: mysql -u " & project & " -p -S " & dir & "/data/mysql.sock"

proc cmdRemove(project: string) =
  if project.len == 0: quit("Usage: " & scriptName & " remove <project>\n", 1)
  if not projectExists(project): quit("Project '" & project & "' does not exist.\n", 1)
  stdout.write("Remove '" & project & "'? [y/N] ")
  if readLine(stdin).toLowerAscii() == "y":
    removeDir(BASE / project)
    echo "Removed."
  else:
    echo "Cancelled."

proc cmdStart(project: string) =
  if project.len == 0: quit("Usage: " & scriptName & " start <project>\n", 1)
  if not projectExists(project): quit("Project '" & project & "' does not exist.\n", 1)
  if isRunning(project):
    echo "Already running."
    return
  let dir = BASE / project
  echo "Starting " & project & "..."
  runBackground(dir / "scripts" / "start")
  if waitForSocket(dir / "data" / "mysql.sock"):
    echo "Running on port " & getPort(project)
  else:
    echo "Warning: Socket not found after 30s, check logs"

proc cmdStop(project: string) =
  if project.len == 0: quit("Usage: " & scriptName & " stop <project>\n", 1)
  if not projectExists(project): quit("Project '" & project & "' does not exist.\n", 1)
  if not isRunning(project):
    echo "Not running."
    return
  let dir = BASE / project
  echo "Stopping " & project & "..."
  discard execCmd(dir / "scripts" / "stop")
  sleep(2000)
  echo "Stopped."

proc cmdList() =
  echo "Instances in " & BASE & ":"
  var found = false
  for kind, path in walkDir(BASE):
    if kind == pcDir:
      let name = path.extractFilename()
      if name == "bin" or name == "backups": continue
      found = true
      let port = getPort(name)
      let portStr = if port.len > 0: port else: "-"
      let status = if isRunning(name): "running" else: "stopped"
      echo "  " & name & "  (port: " & portStr & ", " & status & ")"
  if not found:
    echo "  (none)"

proc cmdInfo(project: string) =
  if project.len == 0: quit("Usage: " & scriptName & " info <project>\n", 1)
  if not projectExists(project): quit("Project '" & project & "' does not exist.\n", 1)
  let dir = BASE / project
  let port = getPort(project)
  let portStr = if port.len > 0: port else: "-"
  let status = if isRunning(project): "running" else: "stopped"
  let (sizeOut, _) = execCmdEx("du -sh '" & dir & "/data' 2>/dev/null")
  let size = sizeOut.split('\t')[0].strip()
  echo "Project:   " & project
  echo "Base dir:  " & dir
  echo "Data dir:  " & dir & "/data"
  echo "Config:    " & dir & "/etc/my.cnf"
  echo "Logs:      " & dir & "/logs/error.log"
  echo "Port:      " & portStr
  echo "Status:    " & status
  echo "DB name:   " & project
  echo "DB user:   " & project
  echo "DB pass:   " & MYSQL_PASS
  echo "Data size: " & (if size.len > 0: size else: "-")

proc cmdPort(project: string) =
  if project.len == 0: quit("Usage: " & scriptName & " port <project>\n", 1)
  if not projectExists(project): quit("Project '" & project & "' does not exist.\n", 1)
  echo getPort(project)

proc cmdLogs(project: string) =
  if project.len == 0: quit("Usage: " & scriptName & " logs <project>\n", 1)
  if not projectExists(project): quit("Project '" & project & "' does not exist.\n", 1)
  let log = BASE / project / "logs" / "error.log"
  if not fileExists(log):
    echo "No log file at " & log
    return
  discard execCmd("tail -n 100 '" & log & "'")

proc cmdBackup(project: string) =
  if project.len == 0: quit("Usage: " & scriptName & " backup <project>\n", 1)
  if not projectExists(project): quit("Project '" & project & "' does not exist.\n", 1)
  let dir = BASE / project
  let tempStarted = ensureRunningForOp(project)
  let ts = now().format("yyyyMMdd-HHmmss")
  let outFile = BACKUPS / project & "-" & ts & ".sql"
  echo "Creating backup: " & outFile
  if not runCmd("'" & MYSQLDUMP & "' --socket='" & dir & "/data/mysql.sock' -u root '" & project & "' > '" & outFile & "'"):
    quit("Backup failed\n", 1)
  if tempStarted: discard execCmd(dir / "scripts" / "stop")
  echo "Backup created: " & outFile

proc cmdRestore(project, file: string) =
  if project.len == 0 or file.len == 0:
    quit("Usage: " & scriptName & " restore <project> <file.sql>\n", 1)
  if not projectExists(project): quit("Project '" & project & "' does not exist.\n", 1)
  if not fileExists(file): quit("File '" & file & "' does not exist.\n", 1)
  let dir = BASE / project
  let tempStarted = ensureRunningForOp(project)
  echo "Restoring " & file & " into " & project & "..."
  if not runCmd("'" & MYSQL_CLIENT & "' --socket='" & dir & "/data/mysql.sock' -u root '" & project & "' < '" & file & "'"):
    quit("Restore failed\n", 1)
  if tempStarted: discard execCmd(dir / "scripts" / "stop")
  echo "Restore completed."

proc cmdClone(src, dst: string) =
  if src.len == 0 or dst.len == 0:
    quit("Usage: " & scriptName & " clone <src> <dst>\n", 1)
  if not projectExists(src): quit("Source '" & src & "' does not exist.\n", 1)
  if projectExists(dst): quit("Destination '" & dst & "' exists.\n", 1)
  echo "Cloning " & src & " -> " & dst
  cmdAdd(dst)
  let srcDir = BASE / src
  let dstDir = BASE / dst
  let srcTempStarted = ensureRunningForOp(src)
  let ts = now().format("yyyyMMdd-HHmmss")
  let tmpBackup = BACKUPS / src & "-clone-" & ts & ".sql"
  echo "Creating temporary backup from " & src & "..."
  if not runCmd("'" & MYSQLDUMP & "' --socket='" & srcDir & "/data/mysql.sock' -u root '" & src & "' > '" & tmpBackup & "'"):
    quit("Clone backup failed\n", 1)
  if srcTempStarted: discard execCmd(srcDir / "scripts" / "stop")
  echo "Restoring into " & dst & "..."
  let dstTempStarted = ensureRunningForOp(dst)
  if not runCmd("'" & MYSQL_CLIENT & "' --socket='" & dstDir & "/data/mysql.sock' -u root '" & dst & "' < '" & tmpBackup & "'"):
    quit("Clone restore failed\n", 1)
  if dstTempStarted: discard execCmd(dstDir / "scripts" / "stop")
  echo "Clone completed: " & src & " -> " & dst

proc cmdStatus(project: string) =
  if project.len == 0: quit("Usage: " & scriptName & " status <project>\n", 1)
  if not projectExists(project): quit("Project '" & project & "' does not exist.\n", 1)
  let dir = BASE / project
  let port = getPort(project)
  let sock = dir / "data" / "mysql.sock"
  let log = dir / "logs" / "error.log"
  echo "Project: " & project
  echo "Port:    " & (if port.len > 0: port else: "-")
  echo "Socket:  " & (if isSocket(sock): "present" else: "missing")
  echo "Status:  " & (if isRunning(project): "running" else: "stopped")
  if fileExists(log):
    let (lastLine, _) = execCmdEx("tail -n 1 '" & log & "'")
    let last = lastLine.strip()
    if last.len > 0:
      echo "Last log: " & last

# --- Entry point ---

when isMainModule:
  let args = commandLineParams()
  let cmd = if args.len > 0: args[0] else: "help"

  if cmd in ["--version", "-v"]:
    echo scriptName & " " & VERSION
    quit(0)

  if cmd in ["help", "--help", "-h"]:
    ensureDirs()
    printHelp()
    quit(0)

  ensureDirs()

  if cmd != "debug":
    detectMysql()

  case cmd
  of "add":     cmdAdd(if args.len > 1: args[1] else: "")
  of "remove":  cmdRemove(if args.len > 1: args[1] else: "")
  of "start":   cmdStart(if args.len > 1: args[1] else: "")
  of "stop":    cmdStop(if args.len > 1: args[1] else: "")
  of "list":    cmdList()
  of "info":    cmdInfo(if args.len > 1: args[1] else: "")
  of "port":    cmdPort(if args.len > 1: args[1] else: "")
  of "logs":    cmdLogs(if args.len > 1: args[1] else: "")
  of "backup":  cmdBackup(if args.len > 1: args[1] else: "")
  of "restore": cmdRestore(if args.len > 1: args[1] else: "",
                           if args.len > 2: args[2] else: "")
  of "clone":   cmdClone(if args.len > 1: args[1] else: "",
                         if args.len > 2: args[2] else: "")
  of "status":  cmdStatus(if args.len > 1: args[1] else: "")
  of "debug":   cmdDebug()
  else:
    echo "Unknown command: " & cmd
    printHelp()
    quit(1)
