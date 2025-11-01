
from __future__ import annotations

import glob
import os
import sys
import signal
from multiprocessing import Process
from typing import List

def find_video_devices() -> List[str]:
    """Return a sorted list of /dev/video* paths present on the system."""
    devices = glob.glob('/dev/video*')
    # Filter out non-device entries (some systems may have names like /dev/video.old)
    devices = [d for d in devices if os.path.exists(d) and os.path.basename(d).startswith('video')]
    devices.sort()
    return devices


def show_camera(device: str) -> None:
    """Open a single camera device and show frames in a window until 'q' is pressed."""
    try:
        import cv2
    except Exception as e:
        print(f"OpenCV import failed in process for {device}: {e}")
        return

    # Try to convert /dev/videoN to integer index when possible
    cap = None
    try:
        if device.startswith('/dev/video'):
            idx = int(device.replace('/dev/video', ''))
            cap = cv2.VideoCapture(idx)
        else:
            cap = cv2.VideoCapture(device)
    except Exception:
        # Fallback to passing the path directly
        cap = cv2.VideoCapture(device)

    window_name = f"Camera {os.path.basename(device)}"
    cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)

    if not cap.isOpened():
        print(f"Failed to open camera: {device}")
        # Nothing to show; release and exit this worker
        try:
            cap.release()
        except Exception:
            pass
        return

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                # If reading fails, print and break
                print(f"[{device}] frame read failed or camera disconnected")
                break

            cv2.imshow(window_name, frame)
            # waitKey(1) required to update the window; check for 'q' to quit
            key = cv2.waitKey(1) & 0xFF
            if key == ord('q'):
                break

    except KeyboardInterrupt:
        pass
    finally:
        cap.release()
        try:
            cv2.destroyWindow(window_name)
        except Exception:
            pass


def main() -> int:
    devices = find_video_devices()
    if not devices:
        print("Nessun dispositivo /dev/video* trovato. Prova a connettere le webcam o eseguire come utente con i permessi corretti.")
        # As fallback, try indexes 0..3 to detect cameras via OpenCV numeric indices
        print("Provo a rilevare indices 0..3 come fallback...")
        try:
            import cv2
        except Exception:
            print("OpenCV non è installato. Installa 'opencv-python' e riprova.")
            return 1
        fallback = []
        for i in range(4):
            cap = cv2.VideoCapture(i)
            if cap.isOpened():
                fallback.append(f"/dev/video{i}")
            cap.release()
        if not fallback:
            print("Nessuna camera trovata con indice 0..3. Esco.")
            return 1
        devices = fallback

    procs: List[Process] = []

    def handle_sigint(signum, frame):
        print("Ricevuto segnale di terminazione, chiudo i processi...")
        for p in procs:
            if p.is_alive():
                p.terminate()
        sys.exit(0)

    # Install signal handler to ensure child processes are terminated on Ctrl-C
    signal.signal(signal.SIGINT, handle_sigint)
    signal.signal(signal.SIGTERM, handle_sigint)

    print(f"Trovati dispositivi: {devices}")

    for d in devices:
        p = Process(target=show_camera, args=(d,), daemon=False)
        p.start()
        procs.append(p)
        print(f"Lanciato processo PID={p.pid} per {d}")

    # Wait for all processes to finish
    try:
        for p in procs:
            p.join()
    except KeyboardInterrupt:
        handle_sigint(None, None)

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
