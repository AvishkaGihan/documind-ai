import smtplib
from email.message import EmailMessage

import structlog

from app.config import get_settings

logger = structlog.get_logger(__name__)


def send_password_reset_email(to_email: str, reset_link: str) -> None:
    settings = get_settings()

    if not settings.smtp_host:
        logger.info(
            "password_reset_email_not_sent_smtp_not_configured",
            to_email=to_email,
            reset_link=reset_link,
        )
        return

    from_email = settings.smtp_from_email or settings.smtp_username
    if not from_email:
        logger.warning(
            "password_reset_email_not_sent_missing_sender",
            to_email=to_email,
        )
        return

    message = EmailMessage()
    message["Subject"] = "DocuMind AI password reset"
    message["From"] = from_email
    message["To"] = to_email
    message.set_content(
        "You requested a password reset for your DocuMind AI account. "
        f"Use this link to reset your password: {reset_link}"
    )

    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as smtp:
        if settings.smtp_username:
            smtp.starttls()
            smtp.login(settings.smtp_username, settings.smtp_password)
        smtp.send_message(message)
