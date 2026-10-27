import json
import os
import random
import time

import paho.mqtt.client as mqtt
from dotenv import load_dotenv

load_dotenv()

print("DEBUG LOCAL =", repr(os.getenv("LOCAL")))

LOCAL = os.getenv("LOCAL") == "1"
N = int(os.getenv("VEHICLES", "20"))
EVERY = float(os.getenv("INTERVAL", "2"))
MAX = int(os.getenv("MAX_MESSAGES", "20000"))  # hard cap protects the free tier

c = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="fleet-simulator")

if LOCAL:
    print("Connecting to local MQTT broker...")
    c.connect("localhost", 1883)

else:
    print("Connecting to AWS IoT Core...")
    c.tls_set(
    ca_certs="certs/AmazonRootCA1.pem",
    certfile="certs/device.pem.crt",
    keyfile="certs/private.pem.key"
)
    
    c.connect(os.environ["IOT_ENDPOINT"], 8883, keepalive=60)
    
c.loop_start()

cars = {f"car-{i:03d}": {"lat": 40.71 + random.uniform(-.05, .05),
                         "lon": -74.0 + random.uniform(-.05, .05),
                         "bat": random.uniform(40, 100)} for i in range(N)}
sent = 0

while sent < MAX:
    t0 = time.time()
    for vid, s in cars.items():
        s["lat"] += random.gauss(0, .0005); s["lon"] += random.gauss(0, .0005)
        s["bat"] = max(0, s["bat"] - random.uniform(0, .05))
        p = {"ts": int(time.time() * 1000), "lat": round(s["lat"], 5), "lon": round(s["lon"], 5),
             "speed_kmh": round(max(0, random.gauss(45, 20)), 1), "battery_pct": round(s["bat"], 1)}
        if random.random() < float(os.getenv("FAULT_RATE", "0.01")):
            p.pop("lat")  # fault injection -> exercises the DLQ path
        c.publish(f"fleet/{vid}/telemetry", json.dumps(p), qos=1)
        sent += 1
    time.sleep(max(0, EVERY - (time.time() - t0)))

print("sent", sent)
c.loop_stop(); c.disconnect()