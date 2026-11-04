from decimal import Decimal

from django.db import models, transaction

from apps.core.models import User


class Wallet(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="wallet")
    balance = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    points_balance = models.PositiveBigIntegerField(default=0)
    updated_at = models.DateTimeField(auto_now=True)

    def credit(self, amount, reason, request=None):
        amount = Decimal(amount)
        with transaction.atomic():
            Wallet.objects.select_for_update().get(pk=self.pk)
            self.balance = Decimal(self.balance) + amount
            self.save(update_fields=["balance", "updated_at"])
            return WalletTransaction.objects.create(
                wallet=self,
                amount=amount,
                kind=WalletTransaction.Kind.CREDIT,
                balance_after=self.balance,
                reason=reason,
                request=request,
            )

    def debit(self, amount, reason, request=None):
        amount = Decimal(amount)
        with transaction.atomic():
            wallet = Wallet.objects.select_for_update().get(pk=self.pk)
            if wallet.balance < amount:
                raise ValueError("Insufficient wallet balance.")
            wallet.balance = Decimal(wallet.balance) - amount
            wallet.save(update_fields=["balance", "updated_at"])
            return WalletTransaction.objects.create(
                wallet=wallet,
                amount=amount,
                kind=WalletTransaction.Kind.DEBIT,
                balance_after=wallet.balance,
                reason=reason,
                request=request,
            )

    def credit_points(self, points, reason, request=None):
        points = int(points)
        with transaction.atomic():
            wallet = Wallet.objects.select_for_update().get(pk=self.pk)
            wallet.points_balance += points
            wallet.save(update_fields=["points_balance", "updated_at"])
            return PointTransaction.objects.create(
                wallet=wallet,
                points=points,
                kind=PointTransaction.Kind.CREDIT,
                balance_after=wallet.points_balance,
                reason=reason,
                request=request,
            )

    def debit_points(self, points, reason, request=None):
        points = int(points)
        with transaction.atomic():
            wallet = Wallet.objects.select_for_update().get(pk=self.pk)
            if wallet.points_balance < points:
                raise ValueError("Insufficient points balance.")
            wallet.points_balance -= points
            wallet.save(update_fields=["points_balance", "updated_at"])
            return PointTransaction.objects.create(
                wallet=wallet,
                points=points,
                kind=PointTransaction.Kind.DEBIT,
                balance_after=wallet.points_balance,
                reason=reason,
                request=request,
            )

    def __str__(self):
        return f"Wallet of {self.user.phone}"


class WalletTransaction(models.Model):
    class Kind(models.TextChoices):
        CREDIT = "CREDIT", "Credit"
        DEBIT = "DEBIT", "Debit"

    wallet = models.ForeignKey(
        Wallet, on_delete=models.CASCADE, related_name="transactions"
    )
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    kind = models.CharField(max_length=10, choices=Kind.choices)
    balance_after = models.DecimalField(max_digits=12, decimal_places=2)
    reason = models.CharField(max_length=255)
    request = models.ForeignKey(
        "waste.CollectionRequest",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="wallet_transactions",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.kind} {self.amount} ({self.wallet.user.phone})"


class PointTransaction(models.Model):
    class Kind(models.TextChoices):
        CREDIT = "CREDIT", "Credit"
        DEBIT = "DEBIT", "Debit"

    wallet = models.ForeignKey(
        Wallet, on_delete=models.CASCADE, related_name="point_transactions"
    )
    points = models.PositiveIntegerField()
    kind = models.CharField(max_length=10, choices=Kind.choices)
    balance_after = models.PositiveBigIntegerField()
    reason = models.CharField(max_length=255)
    request = models.ForeignKey(
        "waste.CollectionRequest",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="point_transactions",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.kind} {self.points} points ({self.wallet.user.phone})"


class RewardPolicy(models.Model):
    minimum_redemption_points = models.PositiveIntegerField(default=1000)
    ugx_per_point = models.DecimalField(max_digits=8, decimal_places=2, default=1)
    pickup_points_percent = models.PositiveSmallIntegerField(default=50)
    dropoff_points_percent = models.PositiveSmallIntegerField(default=100)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return "EcoTrace reward policy"


def get_reward_policy():
    policy, _ = RewardPolicy.objects.get_or_create(pk=1)
    return policy


class Redemption(models.Model):
    class Status(models.TextChoices):
        PENDING = "PENDING", "Pending"
        PAID = "PAID", "Paid"
        REJECTED = "REJECTED", "Rejected"

    class Method(models.TextChoices):
        MOBILE_MONEY = "MOBILE_MONEY", "Mobile money"
        AIRTIME = "AIRTIME", "Airtime"

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="redemptions")
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    points_redeemed = models.PositiveIntegerField(default=0)
    method = models.CharField(max_length=20, choices=Method.choices, default=Method.MOBILE_MONEY)
    destination = models.CharField(max_length=30, help_text="Phone number to pay out to")
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    note = models.CharField(max_length=255, blank=True)
    handled_by = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True, related_name="handled_redemptions"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    handled_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"Redeem {self.amount} ({self.status})"


def get_or_create_wallet(user):
    wallet, _ = Wallet.objects.get_or_create(user=user)
    return wallet
