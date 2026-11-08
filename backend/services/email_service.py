import smtplib
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from dotenv import load_dotenv

load_dotenv()

SMTP_HOST = os.getenv("SMTP_HOST")
SMTP_PORT = int(os.getenv("SMTP_PORT"))
SMTP_USER = os.getenv("SMTP_USER")
SMTP_PASS = os.getenv("SMTP_PASS")
SMTP_FROM = os.getenv("SMTP_FROM")


def send_otp_email(receiver_email: str, otp: str):

    subject = "CashScope Password Reset OTP"

    body = f"""
Your CashScope OTP is:

{otp}

This OTP expires in 10 minutes.
"""

    msg = MIMEMultipart()
    msg["From"] = SMTP_FROM
    msg["To"] = receiver_email
    msg["Subject"] = subject
    msg.attach(MIMEText(body, "plain"))

    try:
        print("Connecting to SMTP...")

        server = smtplib.SMTP(SMTP_HOST, SMTP_PORT)
        server.starttls()

        server.login(SMTP_USER, SMTP_PASS)

        server.sendmail(SMTP_FROM, receiver_email, msg.as_string())

        server.quit()

        print("OTP email sent successfully")

    except Exception as e:
        print("Email sending error:", e)
        raise Exception("Failed to send OTP email")