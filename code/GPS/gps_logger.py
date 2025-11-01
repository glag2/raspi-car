import csv
import time
from datetime import datetime
from gps import gps, WATCH_ENABLE

session = gps(mode=WATCH_ENABLE)
path = "/home/gabri/Desktop/GPS/logs/"
filename = datetime.now().strftime('%d_%B_%Y.csv')
filepath = path + filename

print("GPS Logger started. Press Ctrl+C to stop.")
print("file =", filepath)
print("timestamp, latitude, longitude, altitude")

while True:
    try:
        report = session.next()
        if report['class'] == 'TPV' and hasattr(report, 'lat'):
            lat = report.lat
            lon = report.lon
            alt = getattr(report, 'alt', 'N/A')
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            
            with open(filepath, 'a', newline='') as f:
                writer = csv.writer(f)
                writer.writerow([timestamp, lat, lon, alt])
            
            print(f"{timestamp}: {lat}, {lon}, {alt}")

    except Exception as e:
        print(f"Error: {e}")
        time.sleep(1)