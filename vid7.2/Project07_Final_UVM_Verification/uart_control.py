"""RehanBuilds Project 07 — UART-controlled FPGA digital signal generator.

Usage:
  py -m pip install pyserial
  py uart_control.py COM8
  py uart_control.py COM8 --demo

Commands are single bytes. FPGA echoes valid settings, sends ASCII hex for '?',
or '!' for unsupported commands. Hardware waveforms require AD3 measurement.
"""
import argparse
import serial

DUTY = {0: 0, 25: 1, 50: 2, 75: 3}
FREQ = {1000: 4, 2000: 5, 4000: 6, 8000: 7}


def transact(port, command: str) -> str:
    port.write(command.encode('ascii'))
    reply = port.read(1)
    if len(reply) != 1:
        raise TimeoutError(f"No UART reply for {command!r}; check COM port and FPGA programming")
    text = reply.decode('ascii', errors='replace')
    expected = command if command != '?' else None
    if expected is not None and text != expected:
        raise RuntimeError(f"Unexpected FPGA reply for {command!r}: {text!r}")
    return text


def status(port) -> tuple[int, int]:
    nibble = transact(port, '?')
    try:
        code = int(nibble, 16)
    except ValueError as exc:
        raise RuntimeError(f"Invalid status response {nibble!r}") from exc
    frequencies = (1000, 2000, 4000, 8000)
    duties = (0, 25, 50, 75)
    hz = frequencies[(code >> 2) & 3]
    duty = duties[code & 3]
    return hz, duty


def demo(port) -> None:
    tests = ((1000, 50), (1000, 25), (4000, 50), (8000, 75), (2000, 0))
    for hz, duty in tests:
        transact(port, str(FREQ[hz]))
        transact(port, str(DUTY[duty]))
        actual = status(port)
        if actual != (hz, duty):
            raise RuntimeError(f"FAIL: set {(hz, duty)} read {actual}")
        print(f"PASS: requested {hz} Hz, {duty}% — FPGA reports {actual[0]} Hz, {actual[1]}%")
    print("SUCCESS: All five UART configuration/status tests passed.")
    print("NOTE: The script verifies UART/register status, not physical waveform timing.")
    print("Use Analog Discovery 3 Scope for physical frequency/duty verification.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Basys 3 UART-controlled PWM generator")
    parser.add_argument('port', help='COM port, e.g. COM8')
    parser.add_argument('--demo', action='store_true', help='Automated configuration/status checks')
    args = parser.parse_args()
    with serial.Serial(args.port, baudrate=115200, bytesize=8,
                       parity='N', stopbits=1, timeout=3) as port:
        port.reset_input_buffer()
        print(f"Connected to {args.port} at 115200 baud. Press BTNC to reset FPGA if needed.")
        if args.demo:
            demo(port)
            return
        print("Commands: duty 0|25|50|75; freq 1000|2000|4000|8000; status; demo; quit")
        while True:
            try:
                line = input('FPGA> ').strip().lower().split()
            except (EOFError, KeyboardInterrupt):
                print()
                break
            if not line:
                continue
            try:
                if line[0] in ('quit', 'exit', 'q'):
                    break
                elif line[0] == 'status':
                    hz, duty = status(port)
                    print(f"FPGA reports: {hz} Hz, {duty}% duty")
                elif line[0] == 'demo':
                    demo(port)
                elif line[0] == 'duty' and len(line) == 2:
                    setting = int(line[1]); reply = transact(port, str(DUTY[setting]))
                    print(f"Accepted duty {setting}% (echo {reply}); update takes effect at PWM period boundary")
                elif line[0] == 'freq' and len(line) == 2:
                    setting = int(line[1]); reply = transact(port, str(FREQ[setting]))
                    print(f"Accepted frequency {setting} Hz (echo {reply}); update takes effect at PWM period boundary")
                else:
                    print("Unknown command. Type duty 50, freq 4000, status, demo, or quit.")
            except (ValueError, KeyError) as exc:
                print(f"Invalid setting: {exc}")
            except (RuntimeError, TimeoutError) as exc:
                print(f"Communication error: {exc}")

if __name__ == '__main__':
    main()
