# raspi-car

A simple python project to log OBD II, GPS and video data

## Raspberry Configuration

1. Install the latest Raspberry OS 64x full version (ex Raspbian)
2. Config the pi (enable SSH, VNC, config language and timezone, ...)

```bash
sudo raspi-config
sudo apt update && sudo apt upgrade -y
```

3. Check the python version

### Set up the GPS

Install the needed tools:

```bash
sudo apt-get install gpsd gpsd-clients
```

Check if it's actually working

```bash
cgps -s
```

In case it isn't showing up, and you too have a USB GPS module, try to edit the file `sudo nano /etc/default/gpsd`  replacing its content with this code:

```bash
# Devices gpsd should collect to at boot time.
# They need to be read/writeable, either by user gpsd or the group dialout.
DEVICES="/dev/ttyUSB0"

# Other options you want to pass to gpsd
GPSD_OPTIONS="-n"

# Automatically hot add/remove USB GPS devices via gpsdctl
USBAUTO="false"

GPSD_SOCKET="/var/run/gpsd.sock"
```

Navigation:

-sudo apt install flatpak
-flatpak install flathub app.organicmaps.desktop

### Set up the OBD II connection

In my case the OBD II data are retrieved thanks to an ELM 327 device

[connection tutorial video](https://www.youtube.com/watch?v=DABytIdutKk)

P.S. to shutdown the raspberry use `sudo poweroff` .
