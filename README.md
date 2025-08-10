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

### Set up the USB GPS

Install the needed tools:

```bash
sudo apt-get install gpsd gpsd-clients gpsd-tools
```

Check if it's actually working

```bash
cgps -s
```

In case it isn't showing up, and you too have a USB GPS module, try to set a default name to the GPS:

1) Get the GPS info

- `lsusb` (output: Bus 001 Device 005: ID 1546:01a7 U-Blox AG [u-blox 7])

2) Create the gps rules

- `sudo nano /etc/udev/rules.d/99-gps.rules` (file creation)

3) Populate the file with:

- `KERNEL=="ttyACM*", ATTRS{idVendor}=="1546", ATTRS{idProduct}=="01a7", SYMLINK+="gps0"`

4) Edit the file `sudo nano /etc/default/gpsd`  replacing its content with this code:

```bash
# Devices gpsd should collect to at boot time.
# They need to be read/writeable, either by user gpsd or the group dialout.
DEVICES="/dev/gps0"

# Other options you want to pass to gpsd
GPSD_OPTIONS="-n"

# Automatically hot add/remove USB GPS devices via gpsdctl
USBAUTO="true"

GPSD_SOCKET="/var/run/gpsd.sock"
```

5) Apply the modifications

- `sudo udevadm control --reload-rules`
- `sudo udevadm trigger`
- `sudo systemctl stop gpsd.socket gpsd `
- `sudo systemctl daemon-reload `
- `sudo systemctl start gpsd.socket`

Navigation:

-sudo apt install flatpak
-sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo-
-flatpak install flathub app.organicmaps.desktop
-flatpak run app.organicmaps.desktop

- https://pimylifeup.com/raspberry-pi-waydroid/
- waydroid app install https://github.com/devemux86/cruiser/releases/download/5.6.1/cruiser-5.6.1.apk

### Set up the OBD II connection

In my case the OBD II data are retrieved thanks to an ELM 327 device

[connection tutorial video](https://www.youtube.com/watch?v=DABytIdutKk)

P.S. to shutdown the raspberry use `sudo poweroff` .


### Auto start and shutdown

Insert in this file all the command lines that needs to be executed at startup

`sudo nano /etc/xdg/lxsession/LXDE-pi/autostart`
