from decimal import Decimal

from django.db import models, transaction

from apps.core.models import User


class Wallet(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="wallet")
    balance = models.DecimalField(max_digits=12, decimal_places=2, default=0)
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
