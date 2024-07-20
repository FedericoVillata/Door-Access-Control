from datetime import datetime

# Creare un oggetto datetime
now = datetime.now()

# Ottenere il timestamp Unix
timestamp = int(now.timestamp())
print("Timestamp Unix:", timestamp)

# Convertire il timestamp Unix in un oggetto datetime
from_timestamp = datetime.fromtimestamp(timestamp)
print("Da timestamp Unix:", from_timestamp)
