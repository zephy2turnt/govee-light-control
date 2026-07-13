# Govee Light Control Starter

This repo is a fork of `wez/govee2mqtt`, the best maintained bridge I found for
Govee lights. It is LAN-first when your strip supports the Govee LAN API, but it
can also use the Govee cloud API and Govee account login for features that local
control cannot do.

## What You Need

- A Govee WiFi light strip on the same network as the computer/server running this bridge.
- The Govee Home app.
- Docker Desktop, or a Home Assistant box with MQTT already set up.
- An MQTT broker such as Mosquitto.
- Optional but recommended: a Govee API key.

## Why This Project

`govee2mqtt` is the strongest starter choice because it has:

- LAN-first control for supported lights.
- Cloud API fallback for devices/features that are not LAN-capable.
- Home Assistant discovery through MQTT.
- Recent upstream activity and a large user base compared with smaller one-off scripts.

Smaller direct-control repos can be useful for experiments, but this one gives you
the cleanest path to real daily use.

## Get a Govee API Key

1. Open the Govee Home app.
2. Go to the profile/account area.
3. Open `About Us`.
4. Choose `Apply for API Key`.
5. Submit the request with the email on your Govee account.
6. When Govee emails the key to you, paste it into `.env` as `GOVEE_API_KEY`.

The key is not required for every LAN-capable light, but it unlocks cloud API
features and makes discovery/control more reliable.

## Enable LAN Control

For each supported strip:

1. Open the Govee Home app.
2. Open the light strip.
3. Open device settings.
4. Enable `LAN Control` or `LAN API`.

If the toggle is missing, that model probably does not support local LAN
control. It may still work through the cloud API if your API key supports it.

## Set Up the Local Config

From this repo folder:

```bash
cp .env.example .env
```

Then edit `.env` and fill in:

```bash
GOVEE_EMAIL=your-govee-email@example.com
GOVEE_PASSWORD=your-govee-password
GOVEE_API_KEY=your-govee-api-key
GOVEE_MQTT_HOST=localhost
GOVEE_MQTT_PORT=1883
```

Keep `.env` private. It has account secrets.

## Run It

Start your MQTT broker first. Then run:

```bash
docker compose up -d
docker logs govee2mqtt --follow
```

You should see discovery messages in the logs. In Home Assistant, your Govee
devices should appear through the MQTT integration.

## Find Device IDs and MQTT Topics

The easiest path is Home Assistant:

1. Open Home Assistant.
2. Go to `Settings` -> `Devices & services` -> `MQTT`.
3. Find your Govee light entity.
4. Use the entity controls there for power, brightness, effects, and color.

For command-line control, watch MQTT topics while the bridge starts:

```bash
mosquitto_sub -h localhost -t 'homeassistant/#' -v
mosquitto_sub -h localhost -t 'govee/#' -v
```

Look for topics for your light. The bridge uses this command format:

```text
gv2mqtt/light/YOUR_DEVICE_ID/command
```

The device ID appears in the bridge startup logs and in the `command_topic`
inside the Home Assistant MQTT discovery message. Copy it exactly.

## Simple Commands

Turn a light on:

```bash
mosquitto_pub -h localhost -t 'gv2mqtt/light/YOUR_DEVICE_ID/command' -m '{"state":"ON"}'
```

Turn it off:

```bash
mosquitto_pub -h localhost -t 'gv2mqtt/light/YOUR_DEVICE_ID/command' -m '{"state":"OFF"}'
```

Set brightness to 50 percent. This bridge uses a 0-100 brightness scale:

```bash
mosquitto_pub -h localhost -t 'gv2mqtt/light/YOUR_DEVICE_ID/command' -m '{"state":"ON","brightness":50}'
```

Set color to red:

```bash
mosquitto_pub -h localhost -t 'gv2mqtt/light/YOUR_DEVICE_ID/command' -m '{"state":"ON","color":{"r":255,"g":0,"b":0}}'
```

Set color to blue:

```bash
mosquitto_pub -h localhost -t 'gv2mqtt/light/YOUR_DEVICE_ID/command' -m '{"state":"ON","color":{"r":0,"g":80,"b":255}}'
```

If a command does nothing, check the exact `command_topic` from the Home
Assistant MQTT discovery payload. MQTT topic names must match exactly.

## Notes for Your Setup

- I cannot finish the final pairing step without your real lights on the network.
- LAN control only works on supported WiFi models with LAN enabled in the Govee app.
- Cloud control requires your Govee API key, and some API features are rate limited.
- If discovery is weird, set a static IP for the strip in your router, then try
  `GOVEE_LAN_SCAN=192.168.1.123` in `.env` with your strip's real IP.

## Useful Upstream Docs

- `docs/DOCKER.md` for Docker setup.
- `docs/CONFIG.md` for every environment variable.
- `docs/LAN.md` for LAN troubleshooting.
- `docs/SKUS.md` for support notes by device family.
