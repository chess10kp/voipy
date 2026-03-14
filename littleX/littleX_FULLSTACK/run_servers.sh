#!/bin/bash
# Startup script for Voipy with Browser Automation
# This script starts both the Jac Scale server and MCP wrapper server

set -e # Exit on error

# Configuration
JAC_PORT=${JAC_PORT:-8080}
MCP_PORT=${MCP_PORT:-8001}
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
JAC_PID_FILE="$LOG_DIR/jac_server.pid"
MCP_PID_FILE="$LOG_DIR/mcp_server.pid"

# Create logs directory
mkdir -p "$LOG_DIR"

echo "========================================"
echo "Voipy Browser Automation Startup"
echo "========================================"
echo ""
echo "Jac Server Port: $JAC_PORT"
echo "MCP Server Port: $MCP_PORT"
echo "Project Directory: $PROJECT_DIR"
echo ""

# Function to cleanup on exit
cleanup() {
	echo ""
	echo "========================================"
	echo "Shutting down..."
	echo "========================================"

	# Kill MCP server if running
	if [ -f "$MCP_PID_FILE" ]; then
		MCP_PID=$(cat "$MCP_PID_FILE")
		if kill -0 "$MCP_PID" 2>/dev/null; then
			echo "Stopping MCP server (PID: $MCP_PID)..."
			kill "$MCP_PID"
			rm "$MCP_PID_FILE"
		fi
	fi

	# Kill Jac server if running
	if [ -f "$JAC_PID_FILE" ]; then
		JAC_PID=$(cat "$JAC_PID_FILE")
		if kill -0 "$JAC_PID" 2>/dev/null; then
			echo "Stopping Jac server (PID: $JAC_PID)..."
			kill "$JAC_PID"
			rm "$JAC_PID_FILE"
		fi
	fi

	echo "Servers stopped."
	exit 0
}

# Trap cleanup signals
trap cleanup SIGINT SIGTERM

# Check if already running
if [ -f "$JAC_PID_FILE" ] && kill -0 $(cat "$JAC_PID_FILE") 2>/dev/null; then
	echo "Jac server is already running (PID: $(cat $JAC_PID_FILE))"
	echo "Stop it first with: kill $(cat $JAC_PID_FILE)"
	exit 1
fi

if [ -f "$MCP_PID_FILE" ] && kill -0 $(cat "$MCP_PID_FILE") 2>/dev/null; then
	echo "MCP server is already running (PID: $(cat $MCP_PID_FILE))"
	echo "Stop it first with: kill $(cat $MCP_PID_FILE)"
	exit 1
fi

# Start Jac Scale Server
echo "[1/2] Starting Jac Scale server..."
cd "$PROJECT_DIR"
jac start main.jac --port "$JAC_PORT" >"$LOG_DIR/jac_server.log" 2>&1 &
JAC_PID=$!
echo $JAC_PID >"$JAC_PID_FILE"
echo "Jac server started (PID: $JAC_PID) on port $JAC_PORT"
echo "Log: $LOG_DIR/jac_server.log"

# Wait for Jac server to be ready
echo "Waiting for Jac server to start..."
sleep 5

# Test Jac server health
MAX_RETRIES=10
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
	if curl -s -f "http://localhost:$JAC_PORT/" >/dev/null 2>&1; then
		echo "Jac server is ready!"
		break
	fi
	echo "Waiting for Jac server... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
	sleep 2
	RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
	echo "ERROR: Jac server failed to start"
	cleanup
	exit 1
fi

# Start MCP Wrapper Server
echo ""
echo "[2/2] Starting MCP wrapper server..."
export MCP_PORT=$MCP_PORT
export JAC_API_URL="http://localhost:$JAC_PORT"
python3 mcp_wrapper.py >"$LOG_DIR/mcp_server.log" 2>&1 &
MCP_PID=$!
echo $MCP_PID >"$MCP_PID_FILE"
echo "MCP wrapper server started (PID: $MCP_PID) on port $MCP_PORT"
echo "Log: $LOG_DIR/mcp_server.log"

# Final status
echo ""
echo "========================================"
echo "All servers running!"
echo "========================================"
echo ""
echo "Voipy Web App:        http://localhost:$JAC_PORT"
echo "MCP Server:            http://localhost:$MCP_PORT"
echo ""
echo "Server PIDs:"
echo "  Jac:  $JAC_PID"
echo "  MCP:  $MCP_PID"
echo ""
echo "View logs:"
echo "  Jac:  tail -f $LOG_DIR/jac_server.log"
echo "  MCP:  tail -f $LOG_DIR/mcp_server.log"
echo ""
echo "Press Ctrl+C to stop all servers"
echo ""

# Store MCP port for frontend
echo "$MCP_PORT" >"$LOG_DIR/mcp_port.conf"
echo "MCP port saved to $LOG_DIR/mcp_port.conf"

# Wait for servers
wait
