sleep 15
nohup bash -c 'waydroid show-full-ui' >/dev/null 2>&1 < /dev/null &
sleep 40
gpsctl -n /dev/ttyACM0  &
gpsctl -n /dev/gps0  &
exec /usr/bin/lxterminal -e "bash -c '/home/gabri/Desktop/Waydroid/geobridge-gpsd.sh; exec bash'" &
sleep 30
exec /usr/bin/python3 /home/gabri/Desktop/GPS/gps_logger.py &
sleep 5
exec /usr/bin/python3 /home/gabri/Desktop/DashCam/DashCam_v2.py &