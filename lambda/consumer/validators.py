
REQUIRED = ("vehicle_id", "ts", "lat", "lon", "speed_kmh", "battery_pct")

def validate(e: dict) -> dict:

    missing = [k for k in REQUIRED if k not in e]

    if missing:
        raise ValueError(f"missing fields: {missing}")
    
    if not (-90 <= e["lat"] <= 90 and -180 <= e["lon"] <= 180):
        raise ValueError("Wrong coordinates")
    
    if not (0 <= e["speed_kmh"] <= 250):
        raise ValueError("Wrong speed")
    
    if not (0 <= e["battery_pct"] <= 100):
        raise ValueError("Wrong capacity")
    
    return e