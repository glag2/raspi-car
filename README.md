# raspi-car

A project aimed at using the Raspberry Pi 5 as a GPX navigator (thanks to OsmAnd) while logging OBD II and GPS data.

![1755167269282](image/README/1755167269282.png)

## Raspberry Configuration

1. Install the latest Raspberry OS 64x full version (ex Raspbian)
2. Config the pi (enable SSH, VNC, config language and timezone, ...)

```bash
sudo raspi-config
sudo apt update && sudo apt upgrade -y
```

3. Check the python version
4. Check power status with `vcgencmd get_throttled`

### Set up the USB GPS

Install the needed tools:

```bash
sudo apt-get install gpsd gpsd-clients gpsd-tools socat -y
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

### Navigation

To be able to use a GPX file and the just configured gps we are going to use some APKs thanks to waydroid (it runs Lineage OS behind the scenes).

[Here you can find a guide](https://www.xda-developers.com/run-android-apps-raspberry-pi-how/)

Steps:

1. Select W3 in -> `sudo raspi-config -> advanced -> Wayland -> W3`
2. Add `psi=1` at the end of the file `sudo nano /boot/firmware/cmdline.txt` to enable Pressure Stall Info (to avoid deadlock
3. If `getconf PAGESIZE` retuns 16384 edit the kernel page size by adding `kernel=kernel8.img` in `sudo nano /boot/firmware/config.txt`
4. `echo "deb [signed-by=/usr/share/keyrings/waydroid.gpg] https://repo.waydro.id/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/waydroid.list`
5. `sudo curl -Sf https://repo.waydro.id/waydroid.gpg --output /usr/share/keyrings/waydroid.gpg`
6. `sudo reboot`
7. `sudo apt update && sudo apt udgrade -y`
8. `sudo apt install waydroid -y`
9. `sudo waydroid init`
10. `sudo waydroid container start`
11. `waydroid session start` (in another terminal)
12. `waydroid show-full-ui`
13. `cd Desktop`
14. `mkdir Waydroid`
15. `cd Waydroid`
16. `wget OsmAnd.apk`
17. `waydroid app install OsmAnd.apk`
18. `sudo reboot`
19. `waydroid session start`
20. `waydroid show-full-ui`
21. Open the app

#### Waydroid GPS configuration

install geoclue-2 geoclue-2-demo

1) enable ADB: edit `sudo nano /var/lib/waydroid/waydroid.cfg`, set auto_adb = True
2) `sudo apt-get install adb jq`
3) `adb devices`
4) To allow the connection select "allow" on the popup in waydroid
5) Save the geobridge-gpsd.sh file
6) Execute it with sudo bash geobridge-gpsd.sh --init
7) If the app doesn't install fix the error trying to install it manually
8) run the script without the --init flag to allow the applications to read the location in another terminal
9) `waydroid app launch net.osmand.plus`

*-sudo apt install flatpak
-sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo-
-flatpak install flathub app.organicmaps.desktop
-flatpak run app.organicmaps.desktop*

- > *https://pimylifeup.com/raspberry-pi-waydroid/*
  >
- *cd Desktop/Waydroid*
- *wget https://github.com/devemux86/cruiser/releases/download/5.6.2/cruiser-5.6.2.apk*
- *sudo apt install default-jdk (install java)*
- *waydroid app install cruiser-5.6.2.apk*

### Set up the OBD II connection

In my case the OBD II data are retrieved thanks to an ELM 327 device

[connection tutorial video](https://www.youtube.com/watch?v=DABytIdutKk)

1) bluetoothctl
2) power on
3) pairable on
4) agent on (to enable auto pairing)
5) default-agent (persistant pairing)
6) scan on (to identify the ELM 327 device and to discover its MAC Address)
7) pair MAC-Address (insert yours)
8) trust MAC-Address (to autopair)
9) quit

Get some info from it:

1) sudo rfcomm bind rfcomm0 MAC-Address
2) sudo apt-get install screen
3) screen /dev/rfcomm0
4) atz (to get the device ID)
5) atl1 (enable line feed)
6) ath1 (set display headers)
7) atsp0 01 (auto detect the data port, 01 means get current data, 0c means engine RPM)

   1) it will respond with some hex values, the second to last ones are the value that we are looking for


P.S. to shutdown the raspberry use `sudo poweroff` .

### Auto start and shutdown

Insert in this file all the command lines that needs to be executed at startup

`sudo nano /etc/xdg/lxsession/LXDE-pi/autostart`
