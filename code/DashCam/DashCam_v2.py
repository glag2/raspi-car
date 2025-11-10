"""
Multi-Camera DashCam System
"""

import cv2
import os
import time
import threading
from datetime import datetime

class CameraRecorder(threading.Thread):
    def __init__(self, camera_id, base_dir="./recordings", segment_sec=60, max_files=30):
        super().__init__(daemon=True)
        self.camera_id = camera_id
        self.output_dir = os.path.join(base_dir, f"camera_{camera_id}")
        self.segment_sec = segment_sec
        self.max_files = max_files
        self.running = threading.Event()
        self.running.set()
        
        os.makedirs(self.output_dir, exist_ok=True)
        print(f"[CAM{camera_id}] Output: {self.output_dir}")
        
    def cleanup_old_files(self):
        try:
            files = [os.path.join(self.output_dir, f) for f in os.listdir(self.output_dir) if f.endswith('.mp4')]
            files.sort(key=os.path.getmtime)
            
            while len(files) > self.max_files:
                try:
                    os.remove(files.pop(0))
                except OSError:
                    pass
        except Exception as e:
            print(f"[CAM{self.camera_id}] Cleanup error: {e}")
                
    def run(self):
        print(f"[CAM{self.camera_id}] Starting")
        cap = None
        
        try:
            cap = cv2.VideoCapture(self.camera_id)
            if not cap.isOpened():
                print(f"[CAM{self.camera_id}] ERROR: Cannot open")
                return
            
            # Get properties
            time.sleep(0.5)
            ret, frame = cap.read()
            if not ret or frame is None:
                print(f"[CAM{self.camera_id}] ERROR: Cannot read")
                return
                
            h, w = frame.shape[:2]
            # Forcing 720p resolution if it's lower
            if h < 720 or w < 1280:
                cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
                cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
                time.sleep(0.5)
                ret, frame = cap.read()
                if ret and frame is not None:
                    h, w = frame.shape[:2]
            fps = 30.0 # cap.get(cv2.CAP_PROP_FPS)
            print(f"[CAM{self.camera_id}] {w}x{h} @ {fps}fps")
            
            while self.running.is_set():
                # New file
                filename = f"cam{self.camera_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.mp4"
                filepath = os.path.join(self.output_dir, filename)
                
                writer = cv2.VideoWriter(filepath, cv2.VideoWriter_fourcc(*'mp4v'), fps, (w, h))
                if not writer.isOpened():
                    print(f"[CAM{self.camera_id}] ERROR: Cannot create writer")
                    break
                    
                print(f"[CAM{self.camera_id}] Recording: {filename}")
                
                # Record segment
                start = time.time()
                frames = 0
                
                while (time.time() - start) < self.segment_sec and self.running.is_set():
                    ret, frame = cap.read()
                    if ret and frame is not None:
                        writer.write(frame)
                        frames += 1
                    else:
                        time.sleep(0.01)
                        
                writer.release()
                elapsed = time.time() - start
                if elapsed > 0:
                    print(f"[CAM{self.camera_id}] {frames} frames in {elapsed:.1f}s")
                
                self.cleanup_old_files()
                
        finally:
            if cap:
                cap.release()
            print(f"[CAM{self.camera_id}] Stopped")
        
    def stop(self):
        self.running.clear()


class MultiCameraDashCam:
    def __init__(self, base_dir="recordings", segment_sec=60, max_files=100):
        self.base_dir = base_dir
        self.segment_sec = segment_sec
        self.max_files = max_files
        self.recorders = []
        
    def detect_cameras(self, max_check=5):
        cameras = []
        print("[MAIN] Detecting cameras...")
        
        for i in range(max_check):
            cap = cv2.VideoCapture(i)
            if cap.isOpened():
                ret, _ = cap.read()
                if ret:
                    cameras.append(i)
                    print(f"[MAIN] Found camera {i}")
                cap.release()
                time.sleep(0.1) 
                
        return cameras
        
    def start(self, camera_ids=None):
        if camera_ids is None:
            camera_ids = self.detect_cameras()
            
        if not camera_ids:
            print("[MAIN] No cameras found!")
            return False
            
        print(f"[MAIN] Starting {len(camera_ids)} camera(s)")
        
        for cam_id in camera_ids:
            recorder = CameraRecorder(cam_id, self.base_dir, self.segment_sec, self.max_files)
            recorder.start()
            self.recorders.append(recorder)
            
        return True
        
    def stop(self):
        print("[MAIN] Stopping...")
        for r in self.recorders:
            r.stop()
        for r in self.recorders:
            r.join(timeout=2)
        print("[MAIN] Stopped")
        
    def wait(self):
        try:
            for r in self.recorders:
                r.join()
        except KeyboardInterrupt:
            print("\n[MAIN] Interrupted")
            self.stop()


def main():
    print("=" * 50)
    print("MULTI-CAMERA DASHCAM")
    print("=" * 50)
    
    dashcam = MultiCameraDashCam(base_dir="/home/gabri/Desktop/DashCam/recordings", segment_sec=60, max_files=1000)
    
    if dashcam.start():
        print("[MAIN] Recording... Press Ctrl+C to stop")
        dashcam.wait()
    else:
        print("[MAIN] Failed to start")


if __name__ == "__main__":
    main()