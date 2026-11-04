from django.utils.text import slugify
from rest_framework import serializers

from apps.core.serializers import UserSerializer

from .models import (
    Category,
    Certificate,
    CollectionRequest,
    DropOffPoint,
    Item,
    ItemType,
    ProcessingRecord,
    RequestEvent,
)


class ItemTypeSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source="category.name", read_only=True)

    class Meta:
        model = ItemType
        fields = [
            "id",
            "category",
            "category_name",
            "name",
            "points_per_item",
            "reward_ugx",
            "carbon_factor_kg",
            "hazardous",
            "is_active",
        ]


class CategorySerializer(serializers.ModelSerializer):
    types = ItemTypeSerializer(many=True, read_only=True)
    slug = serializers.SlugField(required=False, allow_blank=True)

    class Meta:
        model = Category
        fields = ["id", "name", "slug", "icon", "is_active", "types"]

    def create(self, validated_data):
        slug = validated_data.pop("slug", "") or slugify(validated_data["name"])
        base_slug = slug or "category"
        slug = base_slug
        suffix = 2
        while Category.objects.filter(slug=slug).exists():
            slug = f"{base_slug}-{suffix}"
            suffix += 1
        return Category.objects.create(slug=slug, **validated_data)


class DropOffPointSerializer(serializers.ModelSerializer):
    class Meta:
        model = DropOffPoint
        fields = [
            "id",
            "name",
            "address",
            "town",
            "latitude",
            "longitude",
            "phone",
            "opening_hours",
            "is_active",
        ]


class ItemSerializer(serializers.ModelSerializer):
    type_name = serializers.CharField(source="item_type.name", read_only=True)
    category_name = serializers.CharField(
        source="item_type.category.name", read_only=True
    )
    reward_ugx = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    points = serializers.IntegerField(read_only=True)
    carbon_kg = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    hazardous = serializers.BooleanField(read_only=True)
    consumer_name = serializers.CharField(
        source="consumer.full_name", read_only=True, default=None
    )

    class Meta:
        model = Item
        fields = [
            "id",
            "item_type",
            "type_name",
            "category_name",
            "quantity",
            "condition",
            "notes",
            "photo",
            "reward_ugx",
            "points",
            "carbon_kg",
            "hazardous",
            "consumer_name",
            "created_at",
        ]
        read_only_fields = ["created_at"]


class RequestEventSerializer(serializers.ModelSerializer):
    # actor_id lets clients check "did I do this?" without guessing on names,
    # which are often blank for accounts registered with only a phone number.
    actor_id = serializers.SerializerMethodField()
    actor_name = serializers.SerializerMethodField()

    class Meta:
        model = RequestEvent
        fields = ["id", "status", "note", "actor_id", "actor_name", "created_at"]

    def get_actor_id(self, obj):
        return obj.actor_id

    def get_actor_name(self, obj):
        if obj.actor_id is None:
            return None
        return obj.actor.full_name or obj.actor.phone


class CertificateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Certificate
        fields = ["id", "code", "summary", "carbon_kg", "issued_at"]


class ProcessingRecordSerializer(serializers.ModelSerializer):
    recycler_name = serializers.CharField(
        source="recycler.full_name", read_only=True, default=None
    )

    class Meta:
        model = ProcessingRecord
        fields = [
            "id",
            "items_expected",
            "items_received",
            "method",
            "notes",
            "recycler_name",
            "processed_at",
        ]


class CollectionRequestSerializer(serializers.ModelSerializer):
    items = ItemSerializer(many=True, read_only=True)
    item_ids = serializers.PrimaryKeyRelatedField(
        queryset=Item.objects.all(), many=True, write_only=True, required=False
    )
    events = RequestEventSerializer(many=True, read_only=True)
    certificate = CertificateSerializer(read_only=True)
    processing = ProcessingRecordSerializer(read_only=True)
    consumer_detail = UserSerializer(source="consumer", read_only=True)
    collector_name = serializers.SerializerMethodField()
    assigned_collector = serializers.SerializerMethodField()
    dropoff_point_detail = DropOffPointSerializer(
        source="dropoff_point", read_only=True, default=None
    )
    status_label = serializers.CharField(read_only=True)
    item_count = serializers.SerializerMethodField()
    carbon_kg = serializers.SerializerMethodField()
    hazardous_count = serializers.SerializerMethodField()
    pickup_confirmed = serializers.SerializerMethodField()

    class Meta:
        model = CollectionRequest
        fields = [
            "id",
            "reference",
            "request_type",
            "status",
            "status_label",
            "items",
            "item_ids",
            "item_count",
            "carbon_kg",
            "hazardous_count",
            "dropoff_point",
            "dropoff_point_detail",
            "pickup_address",
            "latitude",
            "longitude",
            "preferred_date",
            "consumer_note",
            "reward_credited",
            "points_earned",
            "pickup_confirmed",
            "pickup_confirmed_at",
            "consumer_detail",
            "collector_name",
            "assigned_collector",
            "events",
            "certificate",
            "processing",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "reference",
            "status",
            "reward_credited",
            "points_earned",
            "pickup_confirmed_at",
            "created_at",
            "updated_at",
        ]

    def get_item_count(self, obj):
        return sum(item.quantity for item in obj.items.all())

    def get_assigned_collector(self, obj):
        return obj.assigned_collector_id

    def get_collector_name(self, obj):
        if obj.assigned_collector_id is None:
            return None
        return obj.assigned_collector.full_name or obj.assigned_collector.phone

    def get_carbon_kg(self, obj):
        if obj.carbon_kg:
            return obj.carbon_kg
        return sum((item.carbon_kg for item in obj.items.all()), 0)

    def get_hazardous_count(self, obj):
        return sum(
            item.quantity for item in obj.items.all() if item.hazardous
        )

    def get_pickup_confirmed(self, obj):
        return obj.pickup_confirmed_at is not None
