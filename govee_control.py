#!/usr/bin/env python3
"""Simple study and sleep presets for Anas's Govee H61B5 light strip."""

import argparse
import ipaddress
import json
import os
import socket
import sys
from typing import Any


# Change this value if the strip gets a new address from the router.
DEFAULT_DEVICE_IP = "10.0.0.86"

# Govee LAN devices listen for control commands on UDP port 4003.
COMMAND_PORT = 4003

# A lower Kelvin value looks warmer/more amber. 2700 K is a warm household white.
WARM_WHITE_KELVIN = 2700


def make_packet(command: str, data: dict[str, Any]) -> bytes:
    """Build the small JSON message expected by the Govee LAN API."""
    message = {"msg": {"cmd": command, "data": data}}
    return json.dumps(message, separators=(",", ":")).encode("utf-8")


def send_command(
    device_ip: str,
    command: str,
    data: dict[str, Any],
    *,
    dry_run: bool = False,
) -> None:
    """Send one UDP command to the light, or print it during a dry run."""
    packet = make_packet(command, data)

    if dry_run:
        print(f"Would send to {device_ip}:{COMMAND_PORT}: {packet.decode()}")
        return

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp_socket:
        udp_socket.sendto(packet, (device_ip, COMMAND_PORT))


def set_warm_white(
    device_ip: str, brightness: int, *, dry_run: bool = False
) -> None:
    """Turn the strip on, select warm white, and set its brightness."""
    # Govee uses colorwc for both RGB colors and white color temperatures.
    # RGB stays at zero when colorTemInKelvin is being used.
    warm_white = {
        "color": {"r": 0, "g": 0, "b": 0},
        "colorTemInKelvin": WARM_WHITE_KELVIN,
    }

    send_command(device_ip, "turn", {"value": 1}, dry_run=dry_run)
    send_command(device_ip, "colorwc", warm_white, dry_run=dry_run)
    send_command(
        device_ip,
        "brightness",
        {"value": brightness},
        dry_run=dry_run,
    )


def study_mode(device_ip: str, *, dry_run: bool = False) -> None:
    """Set a warm white study light at 68 percent brightness."""
    set_warm_white(device_ip, 68, dry_run=dry_run)


def sleep_mode(device_ip: str, *, dry_run: bool = False) -> None:
    """Set a very dim warm white sleep light at 3 percent brightness."""
    set_warm_white(device_ip, 3, dry_run=dry_run)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Set a Govee H61B5 strip to study or sleep mode."
    )
    parser.add_argument("mode", choices=("study", "sleep"))
    parser.add_argument(
        "--ip",
        default=os.getenv("GOVEE_DEVICE_IP", DEFAULT_DEVICE_IP),
        help="Light strip IP address (default: %(default)s)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the UDP messages without changing the light",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        ipaddress.ip_address(args.ip)
    except ValueError:
        print(f"Invalid IP address: {args.ip}", file=sys.stderr)
        return 2

    if args.mode == "study":
        study_mode(args.ip, dry_run=args.dry_run)
    else:
        sleep_mode(args.ip, dry_run=args.dry_run)

    action = "Previewed" if args.dry_run else "Set"
    print(f"{action} {args.mode} mode for the Govee light at {args.ip}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
