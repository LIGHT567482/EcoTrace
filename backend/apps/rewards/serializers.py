from decimal import Decimal

from rest_framework import serializers

from apps.core.serializers import UserSerializer
from apps.waste.models import CollectionRequest

from .models import Redemption, Wallet, WalletTransaction


class WalletSerializer(serializers.ModelSerializer):
    class Meta:
        model = Wallet
        fields = ["id", "balance", "updated_at"]


class WalletTransactionSerializer(serializers.ModelSerializer):
    request_reference = serializers.CharField(
        source="request.reference", read_only=True, default=None
    )

    class Meta:
        model = WalletTransaction
        fields = [
            "id",
            "amount",
            "kind",
            "balance_after",
            "reason",
            "request_reference",
            "created_at",
        ]


class RedemptionSerializer(serializers.ModelSerializer):
    user_detail = UserSerializer(source="user", read_only=True)
    handled_by_name = serializers.CharField(
        source="handled_by.full_name", read_only=True, default=None
    )

    class Meta:
        model = Redemption
        fields = [
            "id",
            "amount",
            "method",
            "destination",
            "status",
            "note",
            "user_detail",
            "handled_by_name",
            "created_at",
            "handled_at",
        ]
        read_only_fields = ["status", "note", "handled_by_name", "handled_at"]


class CreateRedemptionSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=12, decimal_places=2, min_value=Decimal("0.01"))
    method = serializers.ChoiceField(choices=Redemption.Method.choices, default=Redemption.Method.MOBILE_MONEY)
    destination = serializers.CharField(max_length=30)

    def validate_destination(self, value):
        cleaned = value.replace(" ", "").replace("+", "")
        if not cleaned.isdigit() or len(cleaned) < 9:
            raise serializers.ValidationError("Enter a valid phone number.")
        return value
