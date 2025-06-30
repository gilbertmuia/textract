import os, json, boto3
from shared_layer.python.validator import (
    parse_key_value_pairs, check_qr_links
)
from utils.logger import setup_logger

logger = setup_logger(__name__)
ddb = boto3.resource("dynamodb").Table(os.environ["PROCESSED_TABLE"])

def handler(event, _ctx):
    """
    event =
      { "original": {bucket,key},
        "pageResults": [  # one entry per page
          { "qr_results": [...], "text": "..." }, ...
        ] }
    """
    pages = event["pageResults"]
    flat_qr = {q for p in pages for q in p["qr_results"]}
    full_text = "\n".join(p["text"] for p in pages)

    kv = parse_key_value_pairs(full_text)
    valid, invalid = check_qr_links(list(flat_qr), kv)
    item = {
        "pk": event["original"]["key"],  # partition key
        "validLinks": valid,
        "invalidLinks": invalid,
        "keyValues": kv,
    }
    ddb.put_item(Item=item)
    logger.info(f"Wrote result to DynamoDB ({len(valid)} valid QR links)")
    return item
