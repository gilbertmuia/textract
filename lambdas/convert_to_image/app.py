import json, os, fitz, tempfile
from utils.s3 import download, upload_bytes
from utils.logger import setup_logger

logger = setup_logger(__name__)

def handler(event, _ctx):
    """
    event = { "bucket": "...", "s3Key": "uploads/abc.pdf" }
    returns { "images": ["processed/abc-page-1.png", ...] }
    """
    bucket, key = event["bucket"], event["s3Key"]
    if key.lower().endswith((".png", ".jpg", ".jpeg")):
        logger.info("Already an image – skipping PDF render")
        return {"images": [key]}

    tmp_dir = tempfile.mkdtemp()
    local_file = os.path.join(tmp_dir, os.path.basename(key))
    download(bucket, key, local_file)

    images = []
    doc = fitz.open(local_file)
    for i, page in enumerate(doc, 1):
        pix = page.get_pixmap()
        out_key = f"processed/{os.path.splitext(key)[0]}-page-{i}.png"
        upload_bytes(bucket, out_key, pix.tobytes("png"), "image/png")
        images.append(out_key)
        logger.info(f"Rendered page {i} -> {out_key}")
    return {"images": images}
