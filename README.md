# raspi-car

A project aimed at using the Raspberry Pi 5 as a GPX navigator (thanks to OsmAnd) while logging OBD II and GPS data.

![1755167269282](image/README/1755167269282.png)

## To Do:

- dashcam
- OBD II

## Raspberry Configuration

1. Install the latest Raspberry OS 64x full version (ex Raspbian) with the official Raspberry Pi Imager (enable SSH, set up the Wi-Fi, configure the keyboard layout and timezone in the Imager settings)
2. Config the pi (Es: enable VNC)

```bash
sudo raspi-config
sudo apt update && sudo apt upgrade -y
```

3. Check the python version
4. Check power status with `vcgencmd get_throttled`
5. `sudo apt-get install python3-full`
6. To serve files execute  `python3 -m http.server 8000` in a specific folder, to download go to `raspberrypi.local:8000/file.name` (if .local has been configured)

### Set up the USB GPS

Install the needed tools:

```bash
sudo apt-get install gpsd gpsd-clients gpsd-tools socat -y
```

Check if it's actually working

```bash
cgps -s
```

NOTE : after some testing I found out that `gpsmon` is way more affidable than `cgps` in my case

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

#### Waydroid GPS configuration

install geoclue-2 geoclue-2-demo

1) enable ADB: edit `sudo nano /var/lib/waydroid/waydroid.cfg`, set auto_adb = True
2) `sudo apt-get install adb jq`
3) `adb devices`
4) To allow the connection select "allow" on the popup in waydroid
5) Save the `sudo nano Desktop/Waydroid/geobridge-gpsd.sh` file with the content of this repo path: `code\utils\Waydroid\geobridge-gpsd.sh`
6) Execute it with `sudo bash  Desktop/Waydroid/geobridge-gpsd.sh --init`
7) If the app doesn't install fix the error trying to install it manually with `waydroid app install /tmp/appium.apk`
8) run the script without the --init flag to allow the applications to read the location in another terminal
9) `waydroid app launch app.organicmaps`

#### Installation of a navigator app

1. `cd Desktop`
2. `mkdir Waydroid`
3. `cd Waydroid`
4. `wget OrganicMaps.apk`
5. `waydroid app install OrganicMaps.apk`
6. `sudo reboot`
7. `waydroid session start`
8. `waydroid show-full-ui`
9. Open the app

### Set up the OBD II connection

In my case the OBD II data are retrieved thanks to an ELM 327 device

[connection tutorial video](https://www.youtube.com/watch?v=DABytIdutKk)

1) `bluetoothctl`
2) `power on`
3) `pairable on`
4) `agent on` (to enable auto pairing)
5) `default-agent` (persistant pairing)
6) `scan on` (to identify the ELM 327 device and to discover its MAC Address)
7) `pair` MAC-Address (insert yours)
8) `trust` MAC-Address (to autopair)
9) `quit`

Get some info from it:

1) `sudo rfcomm bind rfcomm0` MAC-Address (in my case 00:10:CC:4F:36:03)
2) `sudo apt-get install screen`
3) `screen /dev/rfcomm0`
4) `atz `(to get the device ID)
5) `atl1` (enable line feed)
6) `ath1` (set display headers)
7) `atsp0 010c` (auto detect the data port, 01 means get current data, 0c means engine RPM)

   1) it will respond with some hex values, the second to last ones are the value that we are looking for

P.S. to shutdown the raspberry use `sudo poweroff` .

### Auto start and shutdown

In order to execute a series of custom commands like:

```bash
sleep 10
nohup bash -c 'waydroid app launch app.organicmaps' >/dev/null 2>&1 < /dev/null & #execute waydroid without a visible terminal
sleep 40
gpsctl -n /dev/ttyACM0 &    # this command tells the gps to return NMEA data, so gpsd can read it
gpsctl -n /dev/gps0 &
exec /usr/bin/lxterminal -e "bash -c '/home/gabri/Desktop/Waydroid/geobridge-gpsd.sh; exec bash'" &
```

we need to create a .sh file, in my case is thisone: /home/gabri/Desktop/Autostart/autostart_manager.sh

now we have to create a custom .desktop file in here: /etc/xdg/autostart/
this is the file that is going to be executed from the next reboot onwards.

edit the file `sudo nano /etc/xdg/autostart/autostart_custom.desktop` with:

```
[Desktop Entry]
Type=Application
Name=Esecuzione comandi custom all'avvio
Exec=/home/gabri/Desktop/Autostart/autostart_manager.sh
Terminal=false
Hidden=false
```
