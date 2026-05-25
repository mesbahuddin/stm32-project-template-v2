#!/usr/bin/env python3
"""
STM32 Serial Terminal — clean and simple.
Just connects serial and passes everything through.
Arrow keys, L/B/Q, all work. Full ANSI support.
"""

import sys, os, time, argparse, threading, ctypes

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pyserial"])
    import serial
    import serial.tools.list_ports

def auto_detect_port():
    ports = list(serial.tools.list_ports.comports())
    for p in ports:
        if p.vid == 0x0483:
            return p.device
    keywords = ["stm32", "virtual com", "usb serial", "ch340", "cp210", "ftdi"]
    for p in ports:
        if any(kw in p.description.lower() for kw in keywords):
            return p.device
    if ports:
        return ports[0].device
    return None

def main():
    parser = argparse.ArgumentParser(description="STM32 Serial Terminal")
    parser.add_argument("-p", "--port", default="")
    parser.add_argument("-b", "--baud", type=int, default=115200)
    args = parser.parse_args()

    # Enable ANSI on Windows console
    kernel32 = ctypes.windll.kernel32
    kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)

    port = args.port or auto_detect_port()
    if not port:
        print("No COM port found")
        sys.exit(1)

    ser = serial.Serial(port=port, baudrate=args.baud, timeout=0.01)
    print(f"\nConnected to {port} at {args.baud} baud")
    print("Arrows=navigate  L=list  B=back  Q=quit  Ctrl+C=exit\n", flush=True)

    # Set console to raw mode for key reading
    import msvcrt

    try:
        while True:
            # Read serial data
            data = ser.read(4096)
            if data:
                sys.stdout.buffer.write(data)
                sys.stdout.flush()

            # Read keystrokes
            if msvcrt.kbhit():
                ch = msvcrt.getch()
                if ch == b'\x03':
                    break
                elif ch in (b'\x00', b'\xe0'):
                    ch2 = msvcrt.getch()
                    mapping = {
                        b'H': b'\x1b[A',  # Up
                        b'P': b'\x1b[B',  # Down
                        b'M': b'\x1b[C',  # Right
                        b'K': b'\x1b[D',  # Left
                    }
                    mapped = mapping.get(ch2)
                    if mapped:
                        ser.write(mapped)
                else:
                    ser.write(ch)
            else:
                time.sleep(0.002)
    except KeyboardInterrupt:
        pass
    finally:
        ser.close()
        print("\nDisconnected.")

if __name__ == "__main__":
    main()
