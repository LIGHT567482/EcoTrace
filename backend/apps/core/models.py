import hashlib
import hmac
from datetime import timedelta

from django.conf import settings
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
from django.utils import timezone


class Role(models.TextChoices):
    CONSUMER = "CONSUMER", "Consumer"
    COLLECTOR = "COLLECTOR", "Collector"
    RECYCLER = "RECYCLER", "Recycler"
    ADMIN = "ADMIN", "Administrator"


class UserManager(BaseUserManager):
    def create_user(self, phone, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)
        if not phone:
            raise ValueError("Users must have a phone number.")
        user = self.model(phone=phone, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, phone, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("role", Role.ADMIN)
        extra_fields.setdefault("is_active", True)
        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")
        return self.create_user(phone, password, **extra_fields)


class User(AbstractUser):
    username = None
    phone = models.CharField(max_length=20, unique=True)
    full_name = models.CharField(max_length=150, blank=True)
    role = models.CharField(max_length=20, choices=Role.choices, default=Role.CONSUMER)
    town = models.CharField(max_length=120, default="Kansanga")
    address = models.CharField(max_length=255, blank=True)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)

    USERNAME_FIELD = "phone"
    REQUIRED_FIELDS = []

    objects = UserManager()

    def __str__(self):
        return f"{self.full_name or self.phone} ({self.role})"


class Notification(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="notifications")
    request_id = models.PositiveIntegerField(null=True, blank=True)
    title = models.CharField(max_length=200)
    body = models.TextField(blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.user_id}: {self.title}"


class StakeholderMessage(models.Model):
    sender = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="sent_stakeholder_messages"
    )
    recipient = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="received_stakeholder_messages"
    )
    body = models.TextField(max_length=2000)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at", "id"]

    def __str__(self):
        return f"Message from {self.sender_id} to {self.recipient_id}"


class AuditLog(models.Model):
    actor = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="audit_logs",
    )
    action = models.CharField(max_length=255)
    method = models.CharField(max_length=10)
    path = models.CharField(max_length=512)
    status_code = models.PositiveSmallIntegerField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.method} {self.path} ({self.status_code})"


class SuspendedSystemSetting(models.Model):
    maintenance_mode = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True)


class PasswordResetRequest(models.Model):
    """Single-use reset code an administrator relays to the account owner.

    There is no SMS or e-mail provider in this system, so the code is derived
    from the server secret instead of being stored: verification and the
    administrator view both recompute it, and nothing sensitive is persisted.
    """

    CODE_TTL = timedelta(minutes=15)

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="password_reset_requests",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    consumed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"Password reset for {self.user_id}"

    @property
    def expires_at(self):
        return self.created_at + self.CODE_TTL

    @property
    def is_consumed(self):
        return self.consumed_at is not None

    @property
    def is_expired(self):
        return timezone.now() >= self.expires_at

    @property
    def is_pending(self):
        return not self.is_consumed and not self.is_expired

    @property
    def code(self):
        material = f"ecotrace:password-reset:{self.pk}".encode()
        digest = hmac.new(
            settings.SECRET_KEY.encode(), material, hashlib.sha256
        ).hexdigest()
        return f"{int(digest[:8], 16) % 1000000:06d}"

    def check_code(self, code):
        return hmac.compare_digest(str(code).strip(), self.code)

    def consume(self):
        self.consumed_at = timezone.now()
        self.save(update_fields=["consumed_at"])


User.Role = Role
