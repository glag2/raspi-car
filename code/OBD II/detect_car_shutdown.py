import time
import subprocess
import obd

# Connessione ELM327 via Bluetooth (modifica l'indirizzo se necessario)
connection = obd.OBD(portstr="/dev/rfcomm0")  # Assicurati che il dispositivo sia associato

def get_rpm():
    response = connection.query(obd.commands.RPM)
    if response.is_null():
        return None
    return response.value.magnitude

def main():
    while True:
        rpm = get_rpm()
        if rpm is not None:
            print(f"Giri motore: {rpm}")
            if rpm <= 300:
                print("Motore spento o al minimo, eseguo shutdown.sh")
                subprocess.run(["bash", "shutdown.sh"])
                break
        else:
            print("Impossibile leggere i giri motore.")
        time.sleep(2)

if __name__ == "__main__":
    main()