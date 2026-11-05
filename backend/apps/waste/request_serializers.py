from rest_framework import serializers

from .models import CollectionRequest, Item


class RequestCreateSerializer(serializers.Serializer):
    request_type = serializers.ChoiceField(
        choices=CollectionRequest.Type.choices, default=CollectionRequest.Type.PICKUP
    )
    item_ids = serializers.ListField(
        child=serializers.IntegerField(), allow_empty=False
    )
    pickup_address = serializers.CharField(max_length=255, required=False, allow_blank=True)
    dropoff_point = serializers.IntegerField(required=False, allow_null=True)
    latitude = serializers.FloatField(required=False, allow_null=True)
    longitude = serializers.FloatField(required=False, allow_null=True)
    preferred_date = serializers.DateField(required=False, allow_null=True)
    consumer_note = serializers.CharField(max_length=255, required=False, allow_blank=True)

    def validate_item_ids(self, value):
        user = self.context["request"].user
        items = Item.objects.filter(pk__in=value, consumer=user)
        if items.count() != len(set(value)):
            raise serializers.ValidationError(
                "One or more items are invalid or do not belong to you."
            )
        return list(items)

    def validate(self, attrs):
        has_latitude = attrs.get("latitude") is not None
        has_longitude = attrs.get("longitude") is not None
        if has_latitude != has_longitude:
            raise serializers.ValidationError(
                {"latitude": "Provide both latitude and longitude."}
            )

        if attrs["request_type"] == CollectionRequest.Type.PICKUP:
                has_address = (
                    attrs.get("pickup_address") or self.context["request"].user.address
                )
                if not has_address and not has_latitude:
                    raise serializers.ValidationError(
                        {
                            "pickup_address": (
                                "A pickup address or map location is required."
                            )
                        }
                    )
        return attrs
