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
        if attrs["request_type"] == CollectionRequest.Type.PICKUP:
            if not attrs.get("pickup_address") and not self.context["request"].user.address:
                raise serializers.ValidationError(
                    {"pickup_address": "A pickup address is required."}
                )
        return attrs
