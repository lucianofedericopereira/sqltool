#!/bin/sh
# tryme.sh - Quick demo of sqltool
# Run this script to see sqltool in action

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SQLTOOL="$SCRIPT_DIR/sqltool"

echo "=== sqltool demo ==="
echo ""

# Make sure sqltool is executable
chmod +x "$SQLTOOL"

echo "1. Creating a test project called 'demo'..."
echo ""
"$SQLTOOL" add demo

echo ""
echo "2. Starting the instance..."
echo ""
"$SQLTOOL" start demo

echo ""
echo "3. Listing all instances..."
echo ""
"$SQLTOOL" list

echo ""
echo "4. Showing instance info..."
echo ""
"$SQLTOOL" info demo

echo ""
echo "5. Creating a test table and inserting data..."
echo ""
mysql -u demo -padmin1234 -S ~/sql/demo/data/mysql.sock demo <<EOF
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com');
INSERT INTO users (name, email) VALUES ('Bob', 'bob@example.com');
SELECT * FROM users;
EOF

echo ""
echo "6. Creating a backup..."
echo ""
"$SQLTOOL" backup demo

echo ""
echo "7. Stopping the instance..."
echo ""
"$SQLTOOL" stop demo

echo ""
echo "=== Demo complete! ==="
echo ""
echo "Your test instance is at: ~/sql/demo/"
echo "Backups are at: ~/sql/backups/"
echo ""
echo "To clean up, run:"
echo "  $SQLTOOL remove demo"
echo ""
echo "To use in your own projects:"
echo "  $SQLTOOL add myproject"
echo "  $SQLTOOL start myproject"
echo "  mysql -u myproject -p -S ~/sql/myproject/data/mysql.sock"
