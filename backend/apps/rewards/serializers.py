from decimal import Decimal

from rest_framework import serializers

from apps.core.serializers import UserSerializer
from apps.waste.models import CollectionRequest

from .models import (
    PointTransaction,
    Redemption,
    RewardPolicy,
    Wallet,
    WalletTransaction,
    get_reward_policy,
)


class WalletSerializer(serializers.ModelSerializer):
    """Wallet with both ledgers: legacy UGX balance and points.

    ``ugx_balance`` is the spendable value in shillings — legacy funds plus
    points converted at the current reward policy — so clients can show one
    number regardless of which ledger credited the reward.
    """

    ugx_balance = serializers.SerializerMethodField()

    class Meta:
        model = Wallet
        fields = [
            "id",
            "balance",
            "points_balance",
            "ugx_balance",
            "updated_at",
        ]

    def get_ugx_balance(self, obj) -> str:
        policy = get_reward_policy()
        total = Decimal(obj.balance) + Decimal(obj.points_balance) * policy.ugx_per_point
        return str(total.quantize(Decimal("0.01")))


class PointTransactionSerializer(serializers.ModelSerializer):
    request_reference = serializers.CharField(
        source="request.reference", read_only=True, default=None
    )

    class Meta:
        model = PointTransaction
        fields = [
            "id",
            "points",
            "kind",
            "balance_after",
            "reason",
            "request_reference",
            "created_at",
        ]


class RewardPolicySerializer(serializers.ModelSerializer):
    minimum_redemption_points = serializers.IntegerField(min_value=1)
    pickup_points_percent = serializers.IntegerField(min_value=0, max_value=100)
    dropoff_points_percent = serializers.IntegerField(min_value=0, max_value=100)

    class Meta:
        model = RewardPolicy
        fields = [
            "minimum_redemption_points",
            "ugx_per_point",
            "pickup_points_percent",
            "dropoff_points_percent",
            "updated_at",
        ]
        read_only_fields = ["updated_at"]

    def validate_ugx_per_point(self, value):
        if value <= 0:
            raise serializers.ValidationError("Point value must be greater than zero.")
        return value

    def validate(self, attrs):
        pickup_percent = attrs.get(
            "pickup_points_percent", self.instance.pickup_points_percent
        )
        dropoff_percent = attrs.get(
            "dropoff_points_percent", self.instance.dropoff_points_percent
        )
        if pickup_percent >= dropoff_percent:
            raise serializers.ValidationError(
                {"pickup_points_percent": "Pickup rewards must stay below drop-off rewards."}
            )
        return attrs


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
            "points_redeemed",
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
    points = serializers.IntegerField(min_value=1, required=False)
    amount = serializers.DecimalField(
        max_digits=12, decimal_places=2, min_value=Decimal("0.01"), required=False
    )
    method = serializers.ChoiceField(choices=Redemption.Method.choices, default=Redemption.Method.MOBILE_MONEY)
    destination = serializers.CharField(max_length=30)

    def validate(self, attrs):
        if ("points" in attrs) == ("amount" in attrs):
            raise serializers.ValidationError(
                "Provide either points to redeem or a legacy wallet amount."
            )
        return attrs

    def validate_destination(self, value):
        cleaned = value.replace(" ", "").replace("+", "")
        if not cleaned.isdigit() or len(cleaned) < 9:
            raise serializers.ValidationError("Enter a valid phone number.")
        return value
