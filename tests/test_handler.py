import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CONSUMER_DIR = PROJECT_ROOT / "lambda" / "consumer"
sys.path.insert(0, str(CONSUMER_DIR))

import handler

import json
from unittest.mock import patch

def make_sqs_record(message_id, payload):
    return {
        "messageId": message_id,
        "body": json.dumps(payload),
    }


def test_valid_message_is_processed():
    event = {
        "Records": [
            make_sqs_record(
                "msg-001",
                {
                    "vehicle_id": "car-001",
                    "lat": 36.8065,
                    "lon": 10.1815,
                    "speed_kmh": 72,
                    "battery_pct": 85,
                    "ts": 1793034000000,
                },
            )
        ]
    }

    with (
        patch.object(handler.table, "put_item") as mock_put,
        patch.object(handler.wr.s3, "to_parquet") as mock_s3,
    ):
        result = handler.handler(event, None)

    assert result == {"batchItemFailures": []}
    mock_put.assert_called_once()
    mock_s3.assert_called_once()