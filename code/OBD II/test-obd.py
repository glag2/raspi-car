import obd
import time

# Establish a connection to the ELM327 device.
# The library will try to auto-detect the port.
# If it fails, you may need to specify the port manually, e.g.:
# connection = obd.OBD("COM3")  # On Windows
# connection = obd.OBD("/dev/rfcomm0")  # On Linux for Bluetooth serial
connection = obd.OBD()

def print_rpm():
    """
    Continuously queries and prints the engine RPM.
    """
    if not connection.is_connected():
        print("Failed to connect to OBD-II adapter.")
        return

    print("Successfully connected to OBD-II adapter.")
    print("Reading RPM... Press Ctrl+C to exit.")

    try:
        while True:
            # Create a command object for RPM
            cmd = obd.commands.RPM
            
            # Send the command and get the response
            response = connection.query(cmd)

            # Check if the response is valid
            if not response.is_null():
                # The value is a Pint Quantity object, get its magnitude
                rpm_value = response.value.magnitude
                print(f"Engine RPM: {rpm_value:.0f}")
            else:
                print("Could not retrieve RPM data. Is the engine running?")

            # Wait for a short period before the next query
            time.sleep(0.5)

    except KeyboardInterrupt:
        print("\nStopping RPM reader.")
    finally:
        # Close the connection
        connection.close()
        print("Connection closed.")

if __name__ == "__main__":
    print_rpm()