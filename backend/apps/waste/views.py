from django.db.models import Count, F, Q, Sum
from django.utils import timezone
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.models import Notification, User
from apps.core.permissions import IsAdmin, IsAdminOrRecycler, IsCollector
from apps.rewards.models import get_or_create_wallet

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
from .request_serializers import RequestCreateSerializer
from .serializers import (
    CategorySerializer,
    CollectionRequestSerializer,
    DropOffPointSerializer,
    ItemSerializer,
    ItemTypeSerializer,
)

STAFF_ROLES = (User.Role.ADMIN, User.Role.COLLECTOR, User.Role.RECYCLER)

ALLOWED_TRANSITIONS = {
    CollectionRequest.Status.PENDING: {
        CollectionRequest.Status.ASSIGNED,
        CollectionRequest.Status.CANCELLED,
    },
    CollectionRequest.Status.ASSIGNED: {
        CollectionRequest.Status.COLLECTED,
        CollectionRequest.Status.PENDING,
        CollectionRequest.Status.CANCELLED,
    },
    CollectionRequest.Status.COLLECTED: {CollectionRequest.Status.IN_TRANSIT},
    CollectionRequest.Status.IN_TRANSIT: {CollectionRequest.Status.RECEIVED},
    CollectionRequest.Status.RECEIVED: {
        CollectionRequest.Status.PROCESSED,
        CollectionRequest.Status.REJECTED,
    },
    CollectionRequest.Status.PROCESSED: set(),
    CollectionRequest.Status.REJECTED: set(),
    CollectionRequest.Status.CANCELLED: set(),
}

COLLECTOR_TRANSITIONS = {
    CollectionRequest.Status.ASSIGNED,
    CollectionRequest.Status.COLLECTED,
    CollectionRequest.Status.IN_TRANSIT,
    CollectionRequest.Status.PENDING,
}


def notify(user, title, body, request_obj=None):
    if user:
        Notification.objects.create(
            user=user,
            request_id=request_obj.id if request_obj else None,
            title=title,
            body=body,
        )


def add_event(request_obj, status_value, note, actor):
    RequestEvent.objects.create(
        request=request_obj, status=status_value, note=note, actor=actor
    )


class CategoryViewSet(viewsets.ModelViewSet):
    queryset = Category.objects.prefetch_related("types")
    serializer_class = CategorySerializer
    permission_classes = [IsAuthenticated]

    def get_permissions(self):
        if self.action in ("list", "retrieve"):
            return [IsAuthenticated()]
        return [IsAdmin()]

    def get_queryset(self):
        qs = super().get_queryset()
        if self.request.user.role not in STAFF_ROLES:
            qs = qs.filter(is_active=True)
        search = self.request.query_params.get("q", "").strip()
        if search:
            qs = qs.filter(Q(name__icontains=search) | Q(types__name__icontains=search))
        return qs.distinct()


class ItemTypeViewSet(viewsets.ModelViewSet):
    queryset = ItemType.objects.select_related("category")
    serializer_class = ItemTypeSerializer
    permission_classes = [IsAuthenticated]

    def get_permissions(self):
        if self.action in ("list", "retrieve"):
            return [IsAuthenticated()]
        return [IsAdmin()]

    def get_queryset(self):
        qs = super().get_queryset()
        if self.request.user.role not in STAFF_ROLES:
            return qs.filter(is_active=True, category__is_active=True)
        if "category" in self.request.query_params:
            qs = qs.filter(category=self.request.query_params["category"])
        search = self.request.query_params.get("q", "").strip()
        if search:
            qs = qs.filter(
                Q(name__icontains=search)
                | Q(category__name__icontains=search)
            )
        return qs


class DropOffPointViewSet(viewsets.ModelViewSet):
    queryset = DropOffPoint.objects.all()
    serializer_class = DropOffPointSerializer
    permission_classes = [IsAuthenticated]

    def get_permissions(self):
        if self.action in ("list", "retrieve"):
            return [AllowAny()]
        return [IsAdmin()]

    def get_queryset(self):
        qs = super().get_queryset()
        town = self.request.query_params.get("town")
        if town:
            qs = qs.filter(town__iexact=town)
        user = self.request.user
        if user.is_anonymous or getattr(user, "role", None) not in STAFF_ROLES:
            return qs.filter(is_active=True)
        return qs


class ItemViewSet(viewsets.ModelViewSet):
    serializer_class = ItemSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role in STAFF_ROLES or user.is_superuser:
            queryset = Item.objects.select_related(
                "item_type__category", "consumer"
            )
        else:
            queryset = Item.objects.filter(consumer=user).select_related(
                "item_type__category", "consumer"
            )
        search = self.request.query_params.get("q", "").strip()
        if search:
            queryset = queryset.filter(
                Q(item_type__name__icontains=search)
                | Q(item_type__category__name__icontains=search)
                | Q(notes__icontains=search)
            )
        return queryset

    def perform_create(self, serializer):
        serializer.save(consumer=self.request.user)

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        if instance.consumer != request.user and not request.user.is_superuser:
            if request.user.role not in STAFF_ROLES:
                return Response(status=status.HTTP_403_FORBIDDEN)
        active = instance.requests.exclude(
            status__in=[
                CollectionRequest.Status.CANCELLED,
                CollectionRequest.Status.REJECTED,
            ]
        )
        if active.exists():
            return Response(
                {"detail": "This item belongs to an active request."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        instance.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class RequestCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = RequestCreateSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        dropoff = None
        if data.get("dropoff_point"):
            dropoff = DropOffPoint.objects.filter(
                pk=data["dropoff_point"], is_active=True
            ).first()
            if dropoff is None:
                return Response(
                    {"dropoff_point": ["Unknown drop-off point."]},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        collection = CollectionRequest.objects.create(
            consumer=request.user,
            request_type=data["request_type"],
            pickup_address=data.get("pickup_address")
            or (request.user.address if data["request_type"] == CollectionRequest.Type.PICKUP else ""),
            dropoff_point=dropoff,
            latitude=data.get("latitude", request.user.latitude),
            longitude=data.get("longitude", request.user.longitude),
            preferred_date=data.get("preferred_date"),
            consumer_note=data.get("consumer_note", ""),
        )
        collection.items.set(data["item_ids"])
        add_event(
            collection,
            CollectionRequest.Status.PENDING,
            "Collection request created",
            request.user,
        )
        return Response(
            CollectionRequestSerializer(collection).data,
            status=status.HTTP_201_CREATED,
        )


class RequestListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        status_filter = request.query_params.get("status")
        town = request.query_params.get("town")
        date_from = request.query_params.get("from")
        date_to = request.query_params.get("to")
        search = request.query_params.get("q")
        scope = request.query_params.get("scope")

        user = request.user
        if user.role == User.Role.CONSUMER:
            qs = user.requests.all()
        elif user.role == User.Role.COLLECTOR:
            if scope == "available":
                # Proposal FR6: requests are matched to collectors in the same town.
                qs = CollectionRequest.objects.filter(
                    status=CollectionRequest.Status.PENDING
                )
                town = town or user.town
            else:
                qs = CollectionRequest.objects.filter(assigned_collector=user)
        elif user.role == User.Role.RECYCLER:
            qs = CollectionRequest.objects.filter(
                status__in=[
                    CollectionRequest.Status.IN_TRANSIT,
                    CollectionRequest.Status.RECEIVED,
                    CollectionRequest.Status.PROCESSED,
                    CollectionRequest.Status.REJECTED,
                ]
            )
        else:
            qs = CollectionRequest.objects.all()

        if status_filter:
            qs = qs.filter(status=status_filter)
        if town and town.lower() != "all":
            qs = qs.filter(consumer__town__iexact=town)
        if date_from:
            qs = qs.filter(created_at__date__gte=date_from)
        if date_to:
            qs = qs.filter(created_at__date__lte=date_to)
        if search:
            qs = qs.filter(
                Q(reference__icontains=search)
                | Q(consumer__full_name__icontains=search)
                | Q(consumer__phone__icontains=search)
                | Q(consumer__town__icontains=search)
                | Q(pickup_address__icontains=search)
                | Q(items__item_type__name__icontains=search)
            ).distinct()

        page = int(request.query_params.get("page", 1))
        per_page = int(request.query_params.get("page_size", 20))
        per_page = min(per_page, 100)
        start = (page - 1) * per_page
        count = qs.count()
        qs = qs.select_related(
            "consumer", "assigned_collector", "dropoff_point"
        ).prefetch_related("items__item_type__category", "certificate", "processing")
        results = qs[start : start + per_page]
        return Response(
            {
                "count": count,
                "page": page,
                "pages": (count + per_page - 1) // per_page,
                "results": CollectionRequestSerializer(results, many=True).data,
            }
        )


class RequestDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk, user):
        obj = (
            CollectionRequest.objects.select_related(
                "consumer", "assigned_collector", "dropoff_point"
            )
            .prefetch_related(
                "items__item_type__category",
                "events__actor",
                "certificate",
                "processing",
            )
            .filter(pk=pk)
            .first()
        )
        if obj is None:
            return None
        if user.role == User.Role.CONSUMER and obj.consumer_id != user.id:
            return None
        if user.role == User.Role.COLLECTOR and obj.assigned_collector_id not in (
            user.id,
            None,
        ):
            if obj.status != CollectionRequest.Status.PENDING:
                return None
        return obj

    def get(self, request, pk):
        obj = self.get_object(pk, request.user)
        if obj is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        return Response(CollectionRequestSerializer(obj).data)


class RequestActionMixin:
    permission_classes = [IsAuthenticated]

    def get_request_or_404(self, pk, user):
        return (
            CollectionRequest.objects.select_related(
                "consumer", "assigned_collector"
            )
            .prefetch_related("items__item_type")
            .filter(pk=pk)
            .first()
        )

    def apply_status(self, request_obj, new_status, note, actor):
        if new_status not in ALLOWED_TRANSITIONS.get(request_obj.status, set()):
            return Response(
                {"detail": f"Cannot move from {request_obj.status} to {new_status}."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        request_obj.status = new_status
        request_obj.save(update_fields=["status", "updated_at"])
        add_event(request_obj, new_status, note, actor)
        labels = dict(CollectionRequest.Status.choices)
        notify(
            request_obj.consumer,
            f"Request {request_obj.reference}: {labels[new_status]}",
            note or f"Your request is now {labels[new_status].lower()}.",
            request_obj,
        )
        if new_status == CollectionRequest.Status.ASSIGNED and actor:
            notify(
                actor,
                f"Pickup assigned: {request_obj.reference}",
                "You have a new collection task.",
                request_obj,
            )
        return Response(CollectionRequestSerializer(request_obj).data)


class ClaimRequestView(RequestActionMixin, APIView):
    def post(self, request, pk):
        if request.user.role != User.Role.COLLECTOR:
            return Response(status=status.HTTP_403_FORBIDDEN)
        obj = self.get_request_or_404(pk, request.user)
        if obj is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        if obj.status != CollectionRequest.Status.PENDING:
            return Response(
                {"detail": "Request is no longer available."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        obj.assigned_collector = request.user
        obj.save(update_fields=["assigned_collector", "updated_at"])
        return self.apply_status(
            obj,
            CollectionRequest.Status.ASSIGNED,
            f"Claimed by {request.user.full_name or request.user.phone}",
            request.user,
        )


class ReleaseRequestView(RequestActionMixin, APIView):
    def post(self, request, pk):
        if request.user.role != User.Role.COLLECTOR:
            return Response(status=status.HTTP_403_FORBIDDEN)
        obj = self.get_request_or_404(pk, request.user)
        if obj is None or obj.assigned_collector_id != request.user.id:
            return Response(status=status.HTTP_404_NOT_FOUND)
        result = self.apply_status(
            obj, CollectionRequest.Status.PENDING, "Released by collector", request.user
        )
        if result.status_code == 200:
            obj.assigned_collector = None
            obj.save(update_fields=["assigned_collector"])
            result = Response(CollectionRequestSerializer(obj).data)
        return result


class TransitionRequestView(RequestActionMixin, APIView):
    def post(self, request, pk):
        user = request.user
        if user.role not in (User.Role.COLLECTOR, User.Role.ADMIN):
            return Response(status=status.HTTP_403_FORBIDDEN)
        obj = self.get_request_or_404(pk, user)
        if obj is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        if user.role == User.Role.COLLECTOR and obj.assigned_collector_id != user.id:
            return Response(
                {"detail": "This request is not assigned to you."},
                status=status.HTTP_403_FORBIDDEN,
            )
        new_status = request.data.get("status")
        note = request.data.get("note", "")
        if new_status not in (
            CollectionRequest.Status.COLLECTED,
            CollectionRequest.Status.IN_TRANSIT,
        ):
            return Response(
                {"detail": "Collectors may only mark COLLECTED or IN_TRANSIT."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if new_status == CollectionRequest.Status.IN_TRANSIT:
            if obj.status != CollectionRequest.Status.COLLECTED:
                return Response(
                    {"detail": "Mark the items as collected first."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        return self.apply_status(obj, new_status, note, user)


class CancelRequestView(RequestActionMixin, APIView):
    def post(self, request, pk):
        obj = self.get_request_or_404(pk, request.user)
        if obj is None or (
            request.user.role == User.Role.CONSUMER and obj.consumer_id != request.user.id
        ):
            return Response(status=status.HTTP_404_NOT_FOUND)
        if request.user.role != User.Role.CONSUMER:
            return Response(status=status.HTTP_403_FORBIDDEN)
        return self.apply_status(
            obj, CollectionRequest.Status.CANCELLED, "Cancelled by consumer", request.user
        )


class ReceiveRequestView(APIView):
    permission_classes = [IsAdminOrRecycler]

    def post(self, request, pk):
        obj = (
            CollectionRequest.objects.select_related("consumer")
            .prefetch_related("items")
            .filter(pk=pk)
            .first()
        )
        if obj is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        if obj.status != CollectionRequest.Status.IN_TRANSIT:
            return Response(
                {"detail": "Request is not in transit."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        expected = sum(item.quantity for item in obj.items.all())
        received = int(request.data.get("items_received", expected))
        ProcessingRecord.objects.create(
            request=obj,
            recycler=request.user,
            items_expected=expected,
            items_received=received,
            method=request.data.get("method", ProcessingRecord.Method.RECYCLING),
            notes=request.data.get("notes", ""),
        )
        obj.status = CollectionRequest.Status.RECEIVED
        obj.save(update_fields=["status", "updated_at"])
        add_event(
            obj,
            CollectionRequest.Status.RECEIVED,
            f"Received {received} of {expected} items at facility",
            request.user,
        )
        notify(
            obj.consumer,
            f"Request {obj.reference} received",
            f"Your items ({received}/{expected}) arrived at the recycling facility.",
            obj,
        )
        return Response(CollectionRequestSerializer(obj).data)


class ProcessRequestView(APIView):
    permission_classes = [IsAdminOrRecycler]

    def post(self, request, pk):
        obj = (
            CollectionRequest.objects.select_related("consumer")
            .prefetch_related("items__item_type")
            .filter(pk=pk)
            .first()
        )
        if obj is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        if obj.status != CollectionRequest.Status.RECEIVED:
            return Response(
                {"detail": "Receive the request before processing it."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        record = ProcessingRecord.objects.filter(request=obj).first()
        method = request.data.get("method")
        if record and method:
            record.method = method
            record.notes = request.data.get("notes", record.notes)
            record.save(update_fields=["method", "notes"])
        elif record is None:
            expected = sum(item.quantity for item in obj.items.all())
            record = ProcessingRecord.objects.create(
                request=obj,
                recycler=request.user,
                items_expected=expected,
                items_received=int(request.data.get("items_received", expected)),
                method=method or ProcessingRecord.Method.RECYCLING,
                notes=request.data.get("notes", ""),
            )

        reward_total = sum((item.reward_ugx for item in obj.items.all()), 0)
        carbon_total = sum((item.carbon_kg for item in obj.items.all()), 0)
        labels = ", ".join(
            sorted({f"{item.item_type.name} x{item.quantity}" for item in obj.items.all()})
        )
        obj.status = CollectionRequest.Status.PROCESSED
        obj.carbon_kg = carbon_total
        if not obj.reward_credited and reward_total > 0:
            wallet = get_or_create_wallet(obj.consumer)
            wallet.credit(
                reward_total,
                f"Reward for disposal {obj.reference}",
                request=obj,
            )
            obj.reward_credited = True
        obj.save(update_fields=["status", "reward_credited", "carbon_kg", "updated_at"])
        Certificate.objects.get_or_create(
            request=obj,
            defaults={
                "issued_to": obj.consumer,
                "summary": labels[:255],
                "carbon_kg": carbon_total,
            },
        )
        add_event(
            obj,
            CollectionRequest.Status.PROCESSED,
            f"Disposal verified; reward UGX {reward_total} credited; "
            f"~{carbon_total} kg Carbon Dioxide equivalent avoided",
            request.user,
        )
        notify(
            obj.consumer,
            f"Disposal verified: {obj.reference}",
            f"Thank you! UGX {reward_total} was credited to your wallet and a "
            "disposal certificate was issued.",
            obj,
        )
        return Response(CollectionRequestSerializer(obj).data)


class RejectRequestView(APIView):
    permission_classes = [IsAdminOrRecycler]

    def post(self, request, pk):
        obj = (
            CollectionRequest.objects.select_related("consumer")
            .filter(pk=pk)
            .first()
        )
        if obj is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        if obj.status != CollectionRequest.Status.RECEIVED:
            return Response(
                {"detail": "Only received requests can be rejected."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        obj.status = CollectionRequest.Status.REJECTED
        obj.save(update_fields=["status", "updated_at"])
        add_event(
            obj,
            CollectionRequest.Status.REJECTED,
            request.data.get("reason", "Consignment rejected at facility"),
            request.user,
        )
        notify(
            obj.consumer,
            f"Request {obj.reference} rejected",
            request.data.get("reason", "The consignment could not be accepted."),
            obj,
        )
        return Response(CollectionRequestSerializer(obj).data)


class StatsView(APIView):
    permission_classes = [IsAdmin]

    def get(self, request):
        requests_qs = CollectionRequest.objects.all()
        date_from = request.query_params.get("from")
        date_to = request.query_params.get("to")
        town = request.query_params.get("town")
        if date_from:
            requests_qs = requests_qs.filter(created_at__date__gte=date_from)
        if date_to:
            requests_qs = requests_qs.filter(created_at__date__lte=date_to)
        if town:
            requests_qs = requests_qs.filter(consumer__town__iexact=town)

        by_status = dict(
            requests_qs.values_list("status").annotate(n=Count("id")).order_by()
        )
        totals = requests_qs.aggregate(
            total_requests=Count("id"),
        )
        processed_requests = requests_qs.filter(
            status=CollectionRequest.Status.PROCESSED
        ).count()
        recycled_items = (
            Item.objects.filter(requests__in=requests_qs).aggregate(
                total=Sum("quantity")
            )["total"]
            or 0
        )
        carbon_saved_kg = (
            requests_qs.filter(status=CollectionRequest.Status.PROCESSED).aggregate(
                total=Sum("carbon_kg")
            )["total"]
            or 0
        )
        from apps.rewards.models import WalletTransaction

        rewards_paid = WalletTransaction.objects.filter(
            kind=WalletTransaction.Kind.CREDIT
        ).aggregate(total=Sum("amount"))["total"] or 0

        # Aggregate request counts and carbon without joining items
        # (a joined Sum/Count would duplicate request rows per item).
        by_town_rows = list(
            requests_qs.values("consumer__town")
            .annotate(requests=Count("id"), carbon_kg=Sum("carbon_kg"))
            .order_by("consumer__town")
            .values("consumer__town", "requests", "carbon_kg")
        )
        item_totals = {
            town: qty
            for town, qty in Item.objects.filter(requests__in=requests_qs)
            .values("requests__consumer__town")
            .annotate(qty=Sum("quantity"))
            .values_list("requests__consumer__town", "qty")
        }
        for row in by_town_rows:
            row["items"] = item_totals.get(row["consumer__town"]) or 0

        return Response(
            {
                "total_requests": totals["total_requests"],
                "by_status": by_status,
                "processed_requests": processed_requests,
                "recycled_items": recycled_items,
                "carbon_saved_kg": carbon_saved_kg,
                "reward_credits_ugx": str(rewards_paid),
                "users_by_role": dict(
                    User.objects.values_list("role").annotate(n=Count("id")).order_by()
                ),
                "towns": dict(
                    User.objects.filter(role=User.Role.CONSUMER)
                    .values_list("town")
                    .annotate(n=Count("id"))
                    .order_by()
                ),
                "by_town": by_town_rows,
                "categories": list(
                    Category.objects.annotate(
                        n=Count("types__items", distinct=True),
                        qty=Sum("types__items__quantity"),
                    ).values("name", "n", "qty")
                ),
            }
        )
