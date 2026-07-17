# Govee to MQTT bridge for Home Assistant

## Anas Quickstart: Study and Sleep Modes

This fork was set up as `zephy2turnt/govee-light-control` so you have a ready
starter repo for controlling Govee light strips through MQTT, Home Assistant,
the Govee LAN API, and the Govee cloud API where needed.

The easiest option is the beginner-friendly `govee_control.py` script. It uses
only Python's built-in modules and sends commands directly to the strip at its
current local IP address, `10.0.0.86`.

### Run it

1. In the Govee Home app, open the H61B5 strip's settings and enable **LAN Control**.
2. Make sure the computer and strip are connected to the same home network.
3. Open Terminal in this repository.
4. Run one of these commands:

```bash
python3 govee_control.py study
python3 govee_control.py sleep
```

- `study` turns the strip on, chooses warm white at 2700 K, and sets brightness to 68%.
- `sleep` turns the strip on, chooses the same warm white, and sets brightness to 3%.
- There are intentionally no music-reactive or color-cycling modes.

To safely preview the exact LAN messages without changing the light:

```bash
python3 govee_control.py study --dry-run
```

### Network ports

The Govee LAN API uses UDP, not TCP:

- UDP `4001`: the strip listens for discovery requests.
- UDP `4002`: the computer listens for discovery and status replies.
- UDP `4003`: the strip listens for power, color-temperature, brightness, and status commands.

Allow local UDP traffic on these ports if a firewall blocks the script. Guest
Wi-Fi or router "client isolation" can prevent devices from talking to each
other even when they appear to be on the same Wi-Fi network.

### If the strip's IP address changes

The script currently defaults to `10.0.0.86`. If that stops working:

1. Run `python3 scripts/govee_lan.py discover` to list LAN-enabled Govee devices.
2. Find the row with model/SKU `H61B5` and copy its new IP address.
3. Test it without editing code:

```bash
python3 govee_control.py study --ip NEW_IP_ADDRESS --dry-run
python3 govee_control.py study --ip NEW_IP_ADDRESS
```

4. For a permanent update, change `DEFAULT_DEVICE_IP` near the top of
   `govee_control.py`, or set an environment variable before running it:

```bash
export GOVEE_DEVICE_IP=NEW_IP_ADDRESS
python3 govee_control.py study
```

Reserving the strip's IP address in the router's DHCP settings is the best way
to keep it from changing again.

### Optional full bridge setup

This repository also contains the larger MQTT/Home Assistant bridge. To use it:

1. Copy `.env.example` to `.env`.
2. For Anas's H61B5, leave the model setting as `GOVEE_TARGET_MODEL=H61B5`.
3. Enable LAN control for the strip in the Govee Home app.
4. Run `python3 scripts/govee_lan.py discover` for key-free local discovery.
5. Follow `STARTER.md` for direct commands or the optional MQTT/Home Assistant bridge.

Do not commit your real `.env`; it contains secrets.

This repo provides a `govee` executable whose primary purpose is to act
as a bridge between [Govee](https://govee.com) devices and Home Assistant,
via the [Home Assistant MQTT Integration](https://www.home-assistant.io/integrations/mqtt/).

## Features

* Robust LAN-first design. Not all of Govee's devices support LAN control,
  but for those that do, you'll have the lowest latency and ability to
  control them even when your primary internet connection is offline.
* Support for per-device modes and scenes.
* Support for the undocumented AWS IoT interface to your devices, provides
  low latency status updates.
* Support for the new [Platform
  API](https://developer.govee.com/reference/get-you-devices) in case the AWS
  IoT or LAN control is unavailable.

|Feature|Requires|Notes|
|-------|--------|-------------|
|DIY Scenes|API Key|Find in the list of Effects for the light in Home Assistant|
|Music Modes|API Key|Find in the list of Effects for the light in Home Assistant|
|Tap-to-Run / One Click Scene|IoT|Find in the overall list of Scenes in Home Assistant, as well as under the `Govee to MQTT` device|
|Live Device Status Updates|LAN and/or IoT|Devices typically report most changes within a couple of seconds.|
|Segment Color|API Key|Find the `Segment 00X` light entities associated with your main light device in Home Assistant|

* `API Key` means that you have [applied for a key from Govee](https://developer.govee.com/reference/apply-you-govee-api-key)
  and have configured it for use in govee2mqtt
* `IoT` means that you have configured your Govee account email and password for
  use in govee2mqtt, which will then attempt to use the
  *undocumented and likely unsupported* AWS MQTT-based IoT service
* `LAN` means that you have enabled the [Govee LAN API](https://app-h5.govee.com/user-manual/wlan-guide)
  on supported devices and that the LAN API protocol is functional on your network

## Usage

* [Installing the HASS Add-On](docs/ADDON.md) - for HAOS and Supervised HASS users
* [Running it in Docker](docs/DOCKER.md)
* [Configuration](docs/CONFIG.md)

## Have a question?

* [Is my device supported?](docs/SKUS.md)
* [Check out the FAQ](docs/FAQ.md)

## Want to show your support or gratitude?

It takes significant effort to build, maintain and support users of software
like this. If you can spare something to say thanks, it is appreciated!

* [Sponsor me on Github](https://github.com/sponsors/wez)
* [Sponsor me on Patreon](https://patreon.com/WezFurlong)
* [Sponsor me on Ko-Fi](https://ko-fi.com/wezfurlong)
* [Sponsor me via liberapay](https://liberapay.com/wez)

## Credits

This work is based on my earlier work with [Govee LAN
Control](https://github.com/wez/govee-lan-hass/).

The AWS IoT support was made possible by the work of @bwp91 in
[homebridge-govee](https://github.com/bwp91/homebridge-govee/).
