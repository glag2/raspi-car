import csv
from datetime import datetime, timezone
from gps import gps, WATCH_ENABLE
import os
import time

session = gps(mode=WATCH_ENABLE)
path = "/home/gabri/Desktop/GPS/logs/"
os.makedirs(path, exist_ok=True)

print("Waiting for GPS fix...")
while True:
    try:
        report = session.next()
        if report['class'] == 'TPV' and hasattr(report, 'lat'):
            print("GPS fix acquired.")
            break
    except Exception:
        pass

# waiting for the system date to be updated
time.sleep(30)

filename = datetime.now().strftime('%d_%B_%Y.csv')
filepath = path + filename


# Header standard GPX/CSV
if not os.path.exists(filepath) or os.path.getsize(filepath) == 0:
    with open(filepath, 'a', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['time', 'latitude', 'longitude', 'elevation'])

print("GPS Logger started. Press Ctrl+C to stop.")
print("file =", filepath)

while True:
    try:
        report = session.next()
        if report['class'] == 'TPV' and hasattr(report, 'lat'):
            timestamp = datetime.now(timezone.utc).isoformat()
            lat = report.lat
            lon = report.lon
            alt = getattr(report, 'alt', '')
            
            with open(filepath, 'a', newline='') as f:
                writer = csv.writer(f)
                writer.writerow([timestamp, lat, lon, alt])
            
            print(f"{timestamp}: {lat}, {lon}, {alt}")

    except Exception as e:
        print(f"Error: {e}")
