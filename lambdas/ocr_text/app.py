import os, json, tempfile
from shared_layer.python.image_processor import extract_text_from_image
from utils.s3 import download, tmp_file
from utils.logger import setup_logger

logger = setup_logger(__name__)

def handler(event, _ctx):
    """
    event = { "bucket": "...", "imageKey": "processed/abc-page-1.png" }
    returns { "text": "..." }
    """
    bucket, key = event["bucket"], event["imageKey"]
    local = tmp_file(".png")
    download(bucket, key, local)

    from PIL import Image
    with Image.open(local) as img:
        text = extract_text_from_image(img)
    logger.info("OCR complete")
    return {"text": text}
