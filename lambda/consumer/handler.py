import json
import logging
import os
import time
from decimal import Decimal

import awswrangler as wr
import boto3
import pandas as pd
from validators import validate

log = logging.getLogger(); log.setLevel(logging.INFO)
table = boto3.resource("dynamodb").Table(os.environ["TABLE"])
BUCKET = os.environ["BUCKET"]

def handler(event, context):

    good, failed = [], []
    
    for r in event["Records"]:
        
        try:

            e = validate(json.loads(r["body"]))
            e["zone"] = f'{round(e["lat"], 2)}_{round(e["lon"], 2)}'
            e["speeding"] = e["speed_kmh"] > 90
            e["processed_ts"] = int(time.time() * 1000)
            e["e2e_ms"] = e["processed_ts"] - e["ts"]
            e["_mid"] = r["messageId"]
            good.append(e)

        except Exception as ex:

            log.warning("invalid record %s: %s", r["messageId"], ex)
            failed.append({"itemIdentifier": r["messageId"]})

    if good:

        try:

            # latest state per vehicle, conditional write handles out-of-order events
            # layesy sayey is stored in dynamodb

            latest = {}

            for e in good:

                if e["vehicle_id"] not in latest or e["ts"] > latest[e["vehicle_id"]]["ts"]:
                    latest[e["vehicle_id"]] = e
            
            for e in latest.values():
                
                item = json.loads(json.dumps({k: v for k, v in e.items() if k != "_mid"}),
                                  parse_float=Decimal)
                
                try:

                    table.put_item(
                        Item=item,
                        ConditionExpression="attribute_not_exists(vehicle_id) OR ts < :t",
                        ExpressionAttributeValues={":t": e["ts"]},
                    )
                
                except table.meta.client.exceptions.ConditionalCheckFailedException:

                    pass  # newer state already stored

            # here all events are stored in S3
            
            df = pd.DataFrame(good).drop(columns=["_mid"])
            t = pd.to_datetime(df["ts"], unit="ms", utc=True)
            df["dt"] = t.dt.strftime("%Y-%m-%d")
            df["hour"] = t.dt.strftime("%H")
            wr.s3.to_parquet(df=df, path=f"s3://{BUCKET}/curated/telemetry/",
                             dataset=True, partition_cols=["dt", "hour"], compression="snappy")
        
        except Exception:

            log.exception("sink failure, retrying whole batch")
            failed += [{"itemIdentifier": e["_mid"]} for e in good]

    log.info("ok=%d failed=%d", len(good), len(failed))

    return {"batchItemFailures": failed}