import cv2
import os
import time
from datetime import datetime
from collections import deque

# Configurazioni
OUT_DIR = "recordings"
FPS = 30   
SEGMENT_SEC = 60    # Durata di ogni file (secondi)
MAX_FILES = 30      # Numero massimo di file da mantenere

def record_segments():
    os.makedirs(OUT_DIR, exist_ok=True)
    cap = cv2.VideoCapture(0)

    if not cap.isOpened():
        raise RuntimeError("Errore: impossibile accedere alla camera.")

    files = deque()

    while True:
        # Legge un frame per stabilire la risoluzione
        ret, frame = cap.read()
        if not ret:
            print("[WARN] Nessun frame letto, controllo camera...")
            time.sleep(1)
            continue

        h, w = frame.shape[:2]

        # Nome file con timestamp
        filename = datetime.now().strftime("%Y%m%d_%H%M%S.mp4")
        filepath = os.path.join(OUT_DIR, filename)

        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        vw = cv2.VideoWriter(filepath, fourcc, FPS, (w, h))
        if not vw.isOpened():
            raise RuntimeError("Errore: impossibile aprire VideoWriter.")

        print(f"[INFO] Registrazione segmento: {filepath}")
        start = time.time()

        while time.time() - start < SEGMENT_SEC:
            ret, frame = cap.read()
            if not ret:
                print("[WARN] Frame perso...")
                time.sleep(0.1)
                continue
            vw.write(frame)

        vw.release()
        files.append(filepath)

        # Controlla tutti i file nella cartella, ordina per data
        all_videos = sorted(
            [os.path.join(OUT_DIR, f) for f in os.listdir(OUT_DIR) if f.endswith(".mp4")],
            key=os.path.getmtime
        )

        # Mantiene solo gli ultimi MAX_FILES
        while len(all_videos) > MAX_FILES:
            old = all_videos.pop(0)
            try:
                os.remove(old)
                print(f"[INFO] Eliminato vecchio file: {old}")
            except Exception as e:
                print(f"[WARN] Non riesco a eliminare {old}: {e}")

if __name__ == "__main__":
    try:
        record_segments()
    except KeyboardInterrupt:
        print("\n[INFO] Interrotto dall'utente, chiusura sicura.")
