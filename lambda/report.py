import boto3
import datetime

s3 = boto3.client("s3")

def handler(event, context):
    today = datetime.date.today().isoformat()

    report = "date,status\n"
    report += f"{today},generated\n"

    s3.put_object(
        Bucket="free-reports-data-bucket-12345",
        Key=f"daily-report-{today}.csv",
        Body=report
    )

    return {"message": "Report created"}
