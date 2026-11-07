from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers

from .models import AuditLog, Notification, StakeholderMessage

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = [
            "id",
            "phone",
            "full_name",
            "role",
            "town",
            "address",
            "latitude",
            "longitude",
            "is_active",
            "date_joined",
        ]
        read_only_fields = ["id", "role", "date_joined"]


class AdminUserSerializer(UserSerializer):
    class Meta(UserSerializer.Meta):
        fields = UserSerializer.Meta.fields + ["is_staff"]
        read_only_fields = ["id", "date_joined"]


class RegisterSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)
    password = serializers.CharField(write_only=True)
    full_name = serializers.CharField(max_length=150, required=False, allow_blank=True)
    town = serializers.CharField(max_length=120, required=False, allow_blank=True)
    address = serializers.CharField(max_length=255, required=False, allow_blank=True)

    def validate_phone(self, value):
        cleaned = value.replace(" ", "").replace("+", "")
        if not cleaned.isdigit() or len(cleaned) < 9:
            raise serializers.ValidationError("Enter a valid phone number.")
        if User.objects.filter(phone=value).exists():
            raise serializers.ValidationError("An account with this phone already exists.")
        return value

    def validate_password(self, value):
        validate_password(value)
        return value

    def create(self, validated_data):
        user = User.objects.create_user(
            phone=validated_data["phone"],
            password=validated_data["password"],
            full_name=validated_data.get("full_name", ""),
            town=validated_data.get("town") or "Kansanga",
            address=validated_data.get("address", ""),
            role=User.Role.CONSUMER,
        )
        return user


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True)

    def validate_new_password(self, value):
        validate_password(value)
        return value


class RequestPasswordResetSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)

    def validate_phone(self, value):
        cleaned = value.strip()
        if not cleaned:
            raise serializers.ValidationError("Enter your phone number.")
        return cleaned


class ConfirmPasswordResetSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)
    code = serializers.CharField(min_length=6, max_length=6)
    new_password = serializers.CharField(write_only=True)

    def validate_new_password(self, value):
        validate_password(value)
        return value


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ["id", "request_id", "title", "body", "is_read", "created_at"]
        read_only_fields = fields


class StakeholderMessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(source="sender.full_name", read_only=True)
    sender_role = serializers.CharField(source="sender.role", read_only=True)
    recipient_name = serializers.CharField(source="recipient.full_name", read_only=True)

    class Meta:
        model = StakeholderMessage
        fields = [
            "id",
            "sender",
            "sender_name",
            "sender_role",
            "recipient",
            "recipient_name",
            "body",
            "is_read",
            "created_at",
        ]
        read_only_fields = fields


class CreateStakeholderMessageSerializer(serializers.Serializer):
    recipient_id = serializers.IntegerField(min_value=1)
    body = serializers.CharField(max_length=2000, trim_whitespace=True)


class StakeholderContactSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "phone", "full_name", "role", "town"]
        read_only_fields = fields


class AuditLogSerializer(serializers.ModelSerializer):
    actor_name = serializers.CharField(
        source="actor.full_name", read_only=True, default=None
    )
    actor_phone = serializers.CharField(
        source="actor.phone", read_only=True, default=None
    )

    class Meta:
        model = AuditLog
        fields = [
            "id",
            "actor_name",
            "actor_phone",
            "action",
            "method",
            "path",
            "status_code",
            "created_at",
        ]
