sleep 15
nohup bash -c 'waydroid app launch app.organicmaps' >/dev/null 2>&1 < /dev/null &
sleep 40
gpsctl -n /dev/ttyACM0  &
gpsctl -n /dev/gps0  &
exec /usr/bin/lxterminal -e "bash -c '/home/gabri/Desktop/Waydroid/geobridge-gpsd.sh; exec bash'" &
