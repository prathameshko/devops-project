import json
import boto3

s3 = boto3.client("s3")

def handler(event, context):
    bucket = event["Records"][0]["s3"]["bucket"]["name"]
    key = event["Records"][0]["s3"]["object"]["key"]

    obj = s3.get_object(Bucket=bucket, Key=key)
    content = obj["Body"].read().decode("utf-8")

    processed = {
        "file": key,
        "length": len(content),
        "status": "processed"
    }

    s3.put_object(
        Bucket="free-processed-data-bucket-12345",
        Key=f"processed-{key}.json",
        Body=json.dumps(processed)
    )

    return {"message": "Data processed"}
