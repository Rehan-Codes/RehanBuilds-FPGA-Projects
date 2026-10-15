"""Project 05 - Basys 3 USB-UART echo test. Requires: pip install pyserial.
Usage: python uart_pc_test.py COM5        # replace COM5 with your actual COM port
"""
import argparse
import serial


def main():
    parser = argparse.ArgumentParser(description="Basys 3 UART echo demonstration")
    parser.add_argument("port", help="Windows serial port, e.g. COM5")
    args = parser.parse_args()

    # 115200 baud, 8 data bits, no parity, 1 stop bit (8N1).
    with serial.Serial(args.port, 115200, timeout=1.5) as port:
        port.reset_input_buffer()
        for value in (0x55, 0xA5, ord("A"), ord("1"), 0x00):
            port.write(bytes([value]))
            received = port.read(1)
            print(f"Sent 0x{value:02X}; Received {received.hex().upper() or 'TIMEOUT'}")
            if received != bytes([value]):
                raise RuntimeError(f"FAIL: expected 0x{value:02X} echo")
        print("SUCCESS: All five UART echo transactions passed.")
        print("FPGA LD7..LD0 should now be OFF (last byte sent was 0x00).")


if __name__ == "__main__":
    main()
