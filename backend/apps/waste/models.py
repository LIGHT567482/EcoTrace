import secrets

from django.conf import settings
from django.db import models

from apps.core.models import User


class Category(models.Model):
    name = models.CharField(max_length=100, unique=True)
    slug = models.SlugField(max_length=100, unique=True)
    icon = models.CharField(max_length=50, blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name_plural = "categories"
        ordering = ["name"]

    def __str__(self):
        return self.name


class ItemType(models.Model):
    category = models.ForeignKey(Category, on_delete=models.CASCADE, related_name="types")
    name = models.CharField(max_length=100)
    reward_ugx = models.DecimalField(
        max_digits=10, decimal_places=2, default=1000.00,
        help_text="Wallet credit per item in UGX",
    )
    carbon_factor_kg = models.DecimalField(
        max_digits=8, decimal_places=2, default=1.0,
        help_text="Estimated Carbon Dioxide avoided per item in kg",
    )
    hazardous = models.BooleanField(
        default=False,
        help_text="Flags components needing specialised hazardous handling",
    )
    is_active = models.BooleanField(default=True)

    class Meta:
        unique_together = ("category", "name")
        ordering = ["name"]

    def __str__(self):
        return f"{self.category.name} / {self.name}"


class DropOffPoint(models.Model):
    name = models.CharField(max_length=150)
    address = models.CharField(max_length=255)
    town = models.CharField(max_length=120, default="Kansanga")
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    phone = models.CharField(max_length=30, blank=True)
    opening_hours = models.CharField(max_length=200, blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class Item(models.Model):
    class Condition(models.TextChoices):
        WORKING = "WORKING", "Working"
        BROKEN = "BROKEN", "Broken"
        DAMAGED = "DAMAGED", "Damaged / hazardous"

    consumer = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="items"
    )
    item_type = models.ForeignKey(ItemType, on_delete=models.PROTECT, related_name="items")
    quantity = models.PositiveIntegerField(default=1)
    condition = models.CharField(
        max_length=20, choices=Condition.choices, default=Condition.BROKEN
    )
    notes = models.CharField(max_length=255, blank=True)
    photo = models.ImageField(upload_to="items/", blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    @property
    def reward_ugx(self):
        return self.item_type.reward_ugx * self.quantity

    @property
    def carbon_kg(self):
        return self.item_type.carbon_factor_kg * self.quantity

    @property
    def hazardous(self):
        return self.item_type.hazardous or self.condition == self.Condition.DAMAGED

    def __str__(self):
        return f"{self.item_type} x{self.quantity}"


class CollectionRequest(models.Model):
    class Type(models.TextChoices):
        PICKUP = "PICKUP", "Pickup"
        DROPOFF = "DROPOFF", "Drop-off"

    class Status(models.TextChoices):
        PENDING = "PENDING", "Pending"
        ASSIGNED = "ASSIGNED", "Assigned"
        COLLECTED = "COLLECTED", "Collected"
        IN_TRANSIT = "IN_TRANSIT", "In transit"
        RECEIVED = "RECEIVED", "Received at facility"
        PROCESSED = "PROCESSED", "Processed"
        REJECTED = "REJECTED", "Rejected"
        CANCELLED = "CANCELLED", "Cancelled"

    reference = models.CharField(max_length=20, unique=True, editable=False)
    consumer = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="requests"
    )
    assigned_collector = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="assigned_requests",
    )
    request_type = models.CharField(max_length=10, choices=Type.choices, default=Type.PICKUP)
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.PENDING
    )
    items = models.ManyToManyField(Item, related_name="requests")
    dropoff_point = models.ForeignKey(
        DropOffPoint,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="requests",
    )
    pickup_address = models.CharField(max_length=255, blank=True)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    preferred_date = models.DateField(null=True, blank=True)
    consumer_note = models.CharField(max_length=255, blank=True)
    reward_credited = models.BooleanField(default=False)
    carbon_kg = models.DecimalField(
        max_digits=10, decimal_places=2, default=0,
        help_text="Estimated Carbon Dioxide avoided, snapshotted when disposal is verified",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def save(self, *args, **kwargs):
        if not self.reference:
            self.reference = f"ET-{secrets.token_hex(4).upper()}"
        super().save(*args, **kwargs)

    @property
    def status_label(self):
        return self.get_status_display()

    def __str__(self):
        return f"{self.reference} ({self.status})"


class RequestEvent(models.Model):
    request = models.ForeignKey(
        CollectionRequest, on_delete=models.CASCADE, related_name="events"
    )
    status = models.CharField(max_length=20, choices=CollectionRequest.Status.choices)
    note = models.CharField(max_length=255, blank=True)
    actor = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True, related_name="events"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]

    def __str__(self):
        return f"{self.request.reference}: {self.status}"


class ProcessingRecord(models.Model):
    class Method(models.TextChoices):
        RECYCLING = "RECYCLING", "Recycling"
        REFURBISHMENT = "REFURBISHMENT", "Refurbishment"
        DISMANTLING = "DISMANTLING", "Dismantling"
        SAFE_DISPOSAL = "SAFE_DISPOSAL", "Safe disposal"

    request = models.OneToOneField(
        CollectionRequest, on_delete=models.CASCADE, related_name="processing"
    )
    recycler = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, related_name="processing_records"
    )
    items_expected = models.PositiveIntegerField(default=0)
    items_received = models.PositiveIntegerField(default=0)
    method = models.CharField(max_length=20, choices=Method.choices, default=Method.RECYCLING)
    notes = models.TextField(blank=True)
    processed_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.request.reference} processed"


class Certificate(models.Model):
    request = models.OneToOneField(
        CollectionRequest, on_delete=models.CASCADE, related_name="certificate"
    )
    code = models.CharField(max_length=30, unique=True, editable=False)
    issued_to = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="certificates"
    )
    summary = models.CharField(max_length=255)
    carbon_kg = models.DecimalField(
        max_digits=10, decimal_places=2, default=0,
        help_text="Estimated Carbon Dioxide avoided for this disposal",
    )
    issued_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-issued_at"]

    def save(self, *args, **kwargs):
        if not self.code:
            self.code = f"ECO-{secrets.token_hex(5).upper()}"
        super().save(*args, **kwargs)

    def __str__(self):
        return self.code
