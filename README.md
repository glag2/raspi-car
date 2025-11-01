# raspi-car

A project aimed at using the Raspberry Pi 5 as a .GPX navigator (thanks to Waydroid) featuring multi-camera dashcam while logging OBD II and GPS data.

![1762005752134](image/README/1762005752134.png)

##### To do list:

- Find a cheap OBD II and **reliable** solution
- Implement the OBD II logic

---

## Raspberry Configuration

1. Install the latest Raspberry OS 64x full version (ex Raspbian) with the official Raspberry Pi Imager (enable SSH if needed, set up the Wi-Fi, configure the keyboard layout and timezone in the Imager settings)
2. Config the pi with `sudo raspi-config` (Es: enable VNC, if you want to operate it remotely)
3. Update and upgrade everything `sudo apt update && sudo apt upgrade -y`
4. Check power status with the bash script `code\utils\get_throttled_decoded.sh` or run `vcgencmd get_throttled`
5. Install the full python package with `sudo apt-get install python3-full -y`
6. Later on we will need to serve files (like the GPX file) to the android container, in order to that, run  `python3 -m http.server 8000` in a specific folder, to download the files inside android, go to `raspberrypi.local:8000/file.name` (if .local has been configured)

Now we are ready to start setting up things, I suggest following step by step all the guide

### Set up the USB GPS

Install the needed tools:

```bash
sudo apt-get install gpsd gpsd-clients gpsd-tools socat -y
```

Check if it's actually working

```bash
cgps -s
```

NOTE : after some testing I found out that `gpsmon` is way more reliable than `cgps` in my case

In case it isn't showing up, and you too have a USB GPS module, try to set a default name to the GPS:

1) Get the GPS info

- `lsusb` (output example: Bus 001 Device 005: ID 1546:01a7 U-Blox AG [u-blox 7]), from now on I'll use these data, remind to replace them with yours

2) Create the GPS rules

- `sudo nano /etc/udev/rules.d/99-gps.rules` (file creation)

3) Add the following to the file:

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

### Automatic GPS date and time

Given the working GPS we can now use it to sync the system date and time using it:

1. Install chrony `sudo apt install chrony`
2. Set it up to use the gps `sudo nano /etc/chrony/chrony.conf`
3. Insert in the file this line `refclock SHM 0 refid NMEA precision 1e-1 offset 0.5 delay 0.2`

### Navigation

To be able to navigate a GPX file and use the just configured gps we are going to use some APKs into waydroid (it runs Lineage OS behind the scenes).

[Here you can find a guide](https://www.xda-developers.com/run-android-apps-raspberry-pi-how/)

Steps:

1. Select W3 in -> `sudo raspi-config -> advanced -> Wayland -> Labwc`
2. Add `psi=1` at the end of the file `sudo nano /boot/firmware/cmdline.txt` to enable Pressure Stall Info (deadlock avoidance)
3. If `getconf PAGESIZE` retuns 16384 edit the kernel page size by adding `kernel=kernel8.img` in `sudo nano /boot/firmware/config.txt`

Run the flollowing commands to install waydroid:

1. `echo "deb [signed-by=/usr/share/keyrings/waydroid.gpg] https://repo.waydro.id/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/waydroid.list`
2. `sudo curl -Sf https://repo.waydro.id/waydroid.gpg --output /usr/share/keyrings/waydroid.gpg`
3. `sudo reboot`
4. `sudo apt update && sudo apt upgrade -y`
5. `sudo apt install waydroid -y`
6. `sudo waydroid init`
7. `sudo waydroid container start`
8. `waydroid session start` (in another terminal)
9. `waydroid show-full-ui`

#### Waydroid GPS configuration

1) enable ADB: edit `sudo nano /var/lib/waydroid/waydroid.cfg`, set auto_adb = True
2) Inside waydroid open the settings app, enable developer mode (repeatedly click build number inside device info), go to the developer settings (System -> Developer options), enable USB debugging, rooted debugging and disable adb auth timeout.
3) `sudo apt-get install adb jq`
4) `adb devices`
5) To allow the connection select "allow" on the popup in waydroid (check "always allow" the box)
6) Save the `sudo nano Desktop/Waydroid/geobridge-gpsd.sh` file with the content of this repo path: `code\Waydroid\geobridge-gpsd.sh`
7) Execute it with `sudo bash  Desktop/Waydroid/geobridge-gpsd.sh --init`
8) If the app doesn't install fix the error trying to install it manually with `waydroid app install /tmp/appium.apk`
9) In another terminal run the script without the --init flag (or run the minimal version) to allow the applications to read the location

#### Installation of a navigator app

1. `cd Desktop`
2. `mkdir Waydroid`
3. `cd Waydroid`
4. `wget OrganicMaps.apk`  (get the apk file here: [https://github.com/organicmaps/organicmaps/releases/](https://github.com/organicmaps/organicmaps/releases/))
5. `waydroid app install OrganicMaps.apk`
6. `sudo reboot`
7. `waydroid session start`
8. `waydroid show-full-ui`
9. Open the app `waydroid app launch app.organicmaps`

Remember to download all the needed maps inside the app before it's too late ;)

To import the GPX file that we want to use follow the point 6 at the beginning of the page.

### Set up the OBD II connection

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

1) `sudo rfcomm bind rfcomm0` MAC-Address
2) `sudo apt-get install screen`
3) `screen /dev/rfcomm0`
4) `atz `(to get the device ID)
5) `atl1` (enable line feed)
6) `ath1` (set display headers)
7) `atsp0 010c` (auto detect the data port, 01 means get current data, 0c means engine RPM)

   it will respond with some hex values, the second to last ones are the value that we are looking for

P.S. to shutdown the raspberry use `sudo poweroff` .

### Dashcam

To be able to record some videos, plug in one or more camera that opencv can see (test it with the file "code\\DashCam\test_all_cams.py"), once plugged in make sure to save the DasCam_v2.py file somewhere and edit the autostart_manager.sh file in order to get it running when the raspberry boot up.

To install open cv in Raspberry OS use this command: `pip install opencv-python --break-system-packages`

### GPS Logger

As for the dashcam, make sure that the GPS works and the code\GPS\gps_logger.py path is correct in the autostart_manager.sh file.

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

Now we have to create a custom .desktop file in here: /etc/xdg/autostart/
This is the file that is going to be executed from the next reboot onwards.

edit the file `sudo nano /etc/xdg/autostart/autostart_custom.desktop` with:

```
[Desktop Entry]
Type=Application
Name=Esecuzione comandi custom all'avvio
Exec=/home/gabri/Desktop/Autostart/autostart_manager.sh
Terminal=false
Hidden=false
```


![1755167269282](https://file+.vscode-resource.vscode-cdn.net/c%3A/Users/gabri/Documents/GitHub/raspi-car/image/README/1755167269282.png)
