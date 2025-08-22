import os
import subprocess
import sys

DEFAULT_CMD = "gpsmon"

def open_terminal_with_command(command: str) -> None:

    term, term_args = ("lxterminal", ["-e", "bash", "-lc", "{cmd}; exec bash"])

    # Format arguments and invoke
    formatted_args = [arg.format(cmd=command) for arg in term_args]
    cmd = [term] + formatted_args
    # Launch asynchronously
    subprocess.Popen(cmd)


if __name__ == "__main__":
    # Allow overriding the command via CLI (useful for testing)
    cmd = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_CMD
    try:
        open_terminal_with_command(cmd)
        print(f"Launched terminal to run: {cmd}")
    except Exception as e:
        print("Error:", e, file=sys.stderr)
        sys.exit(1)

