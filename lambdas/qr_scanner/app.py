import os, json, tempfile
from shared_layer.python.image_processor import scan_qr_from_image
from utils.s3 import download, tmp_file
from utils.logger import setup_logger

logger = setup_logger(__name__)

def handler(event, _ctx):
    """
    event = { "bucket": "...", "imageKey": "processed/abc-page-1.png" }
    returns { "qr_results": [...] }
    """
    bucket, key = event["bucket"], event["imageKey"]
    local = tmp_file(".png")
    download(bucket, key, local)

    from PIL import Image
    with Image.open(local) as img:
        qr_results = scan_qr_from_image(img)
    logger.info(f"Found {len(qr_results)} QR(s) in {key}")
    return {"qr_results": qr_results}
