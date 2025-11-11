from flask import Flask, render_template
import socket
import os
import platform
import psutil
import datetime

app = Flask(__name__)

@app.route('/')
def index():
    # Collect environment information
    host_info = {
        "hostname": socket.gethostname(),
        "ip_address": socket.gethostbyname(socket.gethostname()),
        "os": platform.system(),
        "os_version": platform.version(),
        "python_version": platform.python_version(),
        "cpu_count": psutil.cpu_count(),
        "memory_total": f"{round(psutil.virtual_memory().total / (1024**3), 2)} GB",
        "memory_available": f"{round(psutil.virtual_memory().available / (1024**3), 2)} GB",
        "current_time": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    }
    
    # Add environment variables (filtering out sensitive ones)
    env_vars = {}
    for key, value in sorted(os.environ.items()):
        # Skip sensitive environment variables
        if not any(sensitive in key.lower() for sensitive in ["key", "secret", "token", "password", "auth"]):
            env_vars[key] = value
    
    return render_template('index.html', host_info=host_info, env_vars=env_vars)

if __name__ == '__main__':
    # Get port from environment variable or use 8080 as default
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
