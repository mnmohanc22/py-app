#!/bin/bash

APP_DIR="/opt/myapp"
VENV="$APP_DIR/venv/bin/gunicorn"
APP="wsgi:application"
CONF="$APP_DIR/gunicorn.conf.py"
PID_FILE="/var/run/myapp/gunicorn.pid"
LOG="/var/log/myapp/gunicorn-startup.log"



start() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "Gunicorn already running — PID: $(cat $PID_FILE)"
        exit 1
    fi

    # Ensure PID and log directories exist
    mkdir -p "$(dirname "$PID_FILE")"
    mkdir -p "$(dirname "$LOG")"

    echo "Starting Gunicorn..."
    cd "$APP_DIR"

        ##create venv if not exists
    if [ ! -f "$APP_DIR/venv/bin/activate" ]; then
        echo "Creating venv..."
        python3 -m venv "$APP_DIR/venv"
        "$APP_DIR/venv/bin/pip" install --upgrade pip setuptools wheel -q
        "$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt" -q
        echo "venv created and dependencies installed"
    else
        echo "venv already exists"
    fi  



    source "$APP_DIR/venv/bin/activate"

    nohup "$VENV" "$APP" --config "$CONF" --pid "$PID_FILE" \
        > "$LOG" 2>&1 &

    sleep 2
    if [ -f "$PID_FILE" ]; then
        echo "Gunicorn started — PID: $(cat $PID_FILE)"
    else
        echo "Gunicorn failed to start — check $LOG"
        exit 1
    fi
}

stop() {
    if [ ! -f "$PID_FILE" ]; then
        echo "PID file not found — is Gunicorn running?"
        exit 1
    fi

    echo "Stopping Gunicorn — PID: $(cat $PID_FILE)..."
    kill -TERM $(cat "$PID_FILE")

    # Wait for process to exit
    for i in {1..10}; do
        if ! kill -0 $(cat "$PID_FILE") 2>/dev/null; then
            echo "Gunicorn stopped"
            rm -f "$PID_FILE"
            return
        fi
        sleep 1
    done

    echo "Force killing..."
    kill -9 $(cat "$PID_FILE")
    rm -f "$PID_FILE"
}

restart() {
    stop
    sleep 2
    start
}

reload() {
    if [ ! -f "$PID_FILE" ]; then
        echo "PID file not found"
        exit 1
    fi
    echo "Reloading workers — PID: $(cat $PID_FILE)..."
    kill -HUP $(cat "$PID_FILE")
    echo "Done"
}

status() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "Gunicorn is running — PID: $(cat $PID_FILE)"
        ps aux | grep "[g]unicorn"
    else
        echo "Gunicorn is NOT running"
    fi
}

case "$1" in
    start)   start   ;;
    stop)    stop    ;;
    restart) restart ;;
    reload)  reload  ;;
    status)  status  ;;
    *)
        echo "Usage: $0 {start|stop|restart|reload|status}"
        exit 1
        ;;
esac