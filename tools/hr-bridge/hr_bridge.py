#!/usr/bin/env python3
"""Mac bridge: real-time heart rate from a Huawei watch to the Celia watch app.

The GT 6 Pro can broadcast heart rate over standard Bluetooth LE (Heart Rate Service 0x180D) during a workout
("Share heart rate" in the watch's workout settings). This script subscribes to it and serves the latest value at
    GET http://<mac>:8787/hr  ->  {"bpm": 92, "ts": 1759500000000, "device": "HUAWEI WATCH GT 6 Pro-XXX"}
The emulator's watch app (source "GT 6 Pro (Mac)") polls that endpoint once per second.

Usage:
    python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
    .venv/bin/python hr_bridge.py            # scan for any device that broadcasts heart rate
    .venv/bin/python hr_bridge.py --name GT  # only devices whose name contains "GT"
    .venv/bin/python hr_bridge.py --fake     # no watch: serve a synthetic 60-150 bpm wave (pipeline test)
macOS asks for Bluetooth permission for your terminal app on first run.
"""

import argparse
import asyncio
import json
import math
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HR_SERVICE = "0000180d-0000-1000-8000-00805f9b34fb"
HR_MEASUREMENT = "00002a37-0000-1000-8000-00805f9b34fb"

latest = {"bpm": 0, "ts": 0, "device": ""}
lock = threading.Lock()


def set_latest(bpm: int, device: str) -> None:
    with lock:
        latest["bpm"] = bpm
        latest["ts"] = int(time.time() * 1000)
        latest["device"] = device


def parse_hr_measurement(data: bytearray) -> int:
    """Heart Rate Measurement characteristic: flags bit 0 selects uint8 or uint16 for the value."""
    flags = data[0]
    if flags & 0x01:
        return int.from_bytes(data[1:3], "little")
    return data[1]


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path.rstrip("/") != "/hr":
            self.send_error(404)
            return
        with lock:
            body = json.dumps(latest).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt: str, *args) -> None:  # keep the console for HR lines only
        pass


def serve(port: int) -> None:
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    print(f"serving http://0.0.0.0:{port}/hr")


async def run_fake() -> None:
    start = time.time()
    while True:
        t = time.time() - start
        bpm = int(105 + 45 * math.sin(t / 20))
        set_latest(bpm, "fake")
        print(f"fake {bpm} bpm", flush=True)
        await asyncio.sleep(1)


async def run_ble(name_filter: str) -> None:
    from bleak import BleakClient, BleakScanner  # imported here so --fake works without bleak

    while True:
        print("scanning for heart-rate broadcasts (start a workout with 'Share heart rate' on the watch)...")
        devices = await BleakScanner.discover(timeout=8.0, service_uuids=[HR_SERVICE])
        devices = [d for d in devices if name_filter.lower() in (d.name or "").lower()]
        if not devices:
            print("nothing found, retrying")
            continue
        device = devices[0]
        label = device.name or device.address
        print(f"connecting to {label}")
        try:
            async with BleakClient(device) as client:
                def on_hr(_sender, data: bytearray) -> None:
                    bpm = parse_hr_measurement(data)
                    set_latest(bpm, label)
                    print(f"{label}: {bpm} bpm", flush=True)

                await client.start_notify(HR_MEASUREMENT, on_hr)
                while client.is_connected:
                    await asyncio.sleep(1)
                print("disconnected")
        except Exception as exc:  # BLE drops are normal; just rescan
            print(f"BLE error: {exc}")
        await asyncio.sleep(2)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--name", default="", help="only connect to devices whose name contains this")
    parser.add_argument("--fake", action="store_true", help="serve synthetic heart rate, no Bluetooth")
    args = parser.parse_args()

    serve(args.port)
    try:
        asyncio.run(run_fake() if args.fake else run_ble(args.name))
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
