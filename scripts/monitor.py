#!/usr/bin/env python3
"""
Cross-Platform STM32 Serial Monitor
Auto-detects STM32 Virtual COM Ports, prints color-coded outputs, and handles log files.
Works natively on Windows, macOS, and Linux.
"""

import sys
import os
import time
import argparse
import datetime

# Auto-install/import pyserial
try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("[INFO] 'pyserial' library not found. Attempting to install it automatically...")
    import subprocess
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pyserial"])
        import serial
        import serial.tools.list_ports
        print("[OK] 'pyserial' installed successfully!\n")
    except Exception as e:
        print(f"[ERROR] Failed to install 'pyserial' automatically: {e}")
        print("Please install it manually: pip install pyserial")
        sys.exit(1)

# Terminal color codes (ANSI escape sequences)
class Colors:
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    GRAY = '\033[90m'
    RESET = '\033[0m'
    WHITE = '\033[97m'

def disable_colors_if_unsupported():
    """Disable color coding if the terminal doesn't support it or if redirected."""
    if os.name == 'nt':
        # Enable ANSI escape sequences on Windows 10+
        try:
            import ctypes
            kernel32 = ctypes.windll.kernel32
            kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)
        except Exception:
            # Fall back to disabling colors if Windows API call fails
            Colors.CYAN = Colors.GREEN = Colors.YELLOW = Colors.RED = Colors.GRAY = Colors.RESET = Colors.WHITE = ''
    if not sys.stdout.isatty():
        Colors.CYAN = Colors.GREEN = Colors.YELLOW = Colors.RED = Colors.GRAY = Colors.RESET = Colors.WHITE = ''

def auto_detect_port():
    """Scans system serial ports to auto-detect an STM32 virtual COM port."""
    print("Auto-detecting COM port...")
    ports = list(serial.tools.list_ports.comports())
    
    # Priority 1: Match by STM32 USB Vendor ID (ST's VID is 0483)
    for p in ports:
        if p.vid == 0x0483:
            print(f"{Colors.GREEN}Found STM32 Device (VID:0483) on {p.device} ({p.description}){Colors.RESET}")
            return p.device
            
    # Priority 2: Match by standard keyword substrings
    keywords = ["stm32", "stmicroelectronics", "virtual com", "usb serial", "usb to uart", "ch340", "cp210", "ftdi"]
    for p in ports:
        desc = p.description.lower()
        if any(kw in desc for kw in keywords):
            print(f"{Colors.GREEN}Found compatible port: {p.device} ({p.description}){Colors.RESET}")
            return p.device
            
    # Priority 3: Fall back to first available port
    if ports:
        first_port = ports[0].device
        print(f"{Colors.YELLOW}No explicit STM32 COM port matched. Falling back to first available port: {first_port} ({ports[0].description}){Colors.RESET}")
        return first_port
        
    return None

def colorize_line(line):
    """Applies ANSI colors to lines depending on log severity/content patterns."""
    line_upper = line.upper()
    if any(k in line_upper for k in ["TRIG", "CRITICAL", "FATAL"]):
        return f"{Colors.RED}{line}{Colors.RESET}"
    elif any(k in line_upper for k in ["INIT", "READY", "ACTIVE", "SUCCESS", "OK"]):
        return f"{Colors.GREEN}{line}{Colors.RESET}"
    elif any(k in line_upper for k in ["ERROR", "FAIL", "WARN", "WARNING"]):
        return f"{Colors.YELLOW}{line}{Colors.RESET}"
    return line

def main():
    disable_colors_if_unsupported()
    
    parser = argparse.ArgumentParser(description="Cross-Platform STM32 Serial Monitor")
    parser.add_argument("-p", "--port", default="", help="Serial port (e.g. COM3 or /dev/ttyACM0). Auto-detects if omitted.")
    parser.add_argument("-b", "--baud", type=int, default=115200, help="Baud rate (default: 115200)")
    parser.add_argument("-l", "--log", default="", help="Log output to file")
    parser.add_argument("-t", "--timestamp", action="store_true", help="Prefix each line with a timestamp")
    args = parser.parse_args()

    print(f"{Colors.CYAN}======================================{Colors.RESET}")
    print(f"{Colors.CYAN}        STM32 Serial Monitor          {Colors.RESET}")
    print(f"{Colors.CYAN}======================================{Colors.RESET}\n")

    port = args.port
    if not port:
        port = auto_detect_port()
        
    if not port:
        print(f"{Colors.RED}ERROR: No serial ports detected! Please connect your STM32 device.{Colors.RESET}")
        ports = list(serial.tools.list_ports.comports())
        if ports:
            print("\nAvailable ports:")
            for p in ports:
                print(f"  - {p.device} ({p.description})")
        sys.exit(1)

    print(f"{Colors.YELLOW}Configuration:{Colors.RESET}")
    print(f"  Port:      {Colors.WHITE}{port}{Colors.RESET}")
    print(f"  Baud Rate: {Colors.WHITE}{args.baud}{Colors.RESET}")
    if args.log:
        print(f"  Log File:  {Colors.WHITE}{args.log}{Colors.RESET}")
    if args.timestamp:
        print(f"  Timestamps:Enabled")
    print()

    # Configure Log File
    log_file = None
    if args.log:
        try:
            log_file = open(args.log, "a", encoding="utf-8", errors="ignore")
            log_file.write(f"\n--- Serial log started: {datetime.datetime.now()} ---\n")
            log_file.write(f"Port: {port}, Baud Rate: {args.baud}\n\n")
            log_file.flush()
        except Exception as e:
            print(f"{Colors.YELLOW}WARNING: Could not open log file '{args.log}': {e}{Colors.RESET}")
            log_file = None

    # Connect to serial port
    try:
        ser = serial.Serial(port=port, baudrate=args.baud, timeout=0.1)
    except Exception as e:
        print(f"{Colors.RED}ERROR: Failed to open serial port {port}!{Colors.RESET}")
        print(f"Details: {e}")
        if log_file:
            log_file.close()
        sys.exit(1)

    print(f"{Colors.GREEN}Connected to {port} successfully!{Colors.RESET}")
    print(f"{Colors.GRAY}Press Ctrl+C to exit{Colors.RESET}")
    print(f"{Colors.GRAY}--- START OF OUTPUT ---{Colors.RESET}\n")

    buffer = bytearray()
    
    try:
        while True:
            # Read all available bytes
            data = ser.read(ser.in_waiting or 1)
            if data:
                for b in data:
                    if b == 10:  # Line Feed (\n)
                        # Decode and clean line
                        try:
                            line = buffer.decode("utf-8", errors="ignore").rstrip("\r")
                        except Exception:
                            line = buffer.decode("latin-1", errors="ignore").rstrip("\r")
                        
                        buffer.clear()
                        
                        # Add timestamp if enabled
                        if args.timestamp:
                            now = datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]
                            line_out = f"[{now}] {line}"
                        else:
                            line_out = line
                            
                        # Colorize for console and print
                        print(colorize_line(line_out))
                        
                        # Log to file
                        if log_file:
                            log_file.write(line_out + "\n")
                            log_file.flush()
                    elif b != 13:  # Ignore Carriage Return (\r)
                        buffer.append(b)
                        
            # Sleep slightly to prevent high CPU utilization
            time.sleep(0.002)
            
    except KeyboardInterrupt:
        print(f"\n\n{Colors.GRAY}--- END OF OUTPUT ---{Colors.RESET}")
    finally:
        # Cleanup
        print(f"{Colors.YELLOW}Closing connection...{Colors.RESET}")
        ser.close()
        if log_file:
            log_file.write(f"\n--- Serial log ended: {datetime.datetime.now()} ---\n")
            log_file.close()
            print(f"{Colors.GREEN}Log saved to: {args.log}{Colors.RESET}")
        print(f"{Colors.GREEN}Disconnected safely.{Colors.RESET}")
        print(f"{Colors.CYAN}======================================{Colors.RESET}")

if __name__ == "__main__":
    main()
