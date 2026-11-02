from django.db.models import Q, Sum
from django.utils import timezone
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.models import User
from apps.core.permissions import IsAdmin

from .models import Redemption, WalletTransaction, get_or_create_wallet
from .serializers import (
    CreateRedemptionSerializer,
    RedemptionSerializer,
    WalletSerializer,
    WalletTransactionSerializer,
)


class WalletView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        wallet = get_or_create_wallet(request.user)
        txs = wallet.transactions.all()[:50]
        return Response(
            {
                "wallet": WalletSerializer(wallet).data,
                "transactions": WalletTransactionSerializer(txs, many=True).data,
            }
        )


class RedeemView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = CreateRedemptionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        wallet = get_or_create_wallet(request.user)
        amount = serializer.validated_data["amount"]
        if wallet.balance < amount:
            return Response(
                {"detail": "Insufficient wallet balance."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            wallet.debit(amount, "Redemption requested")
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        redemption = Redemption.objects.create(
            user=request.user,
            amount=amount,
            method=serializer.validated_data["method"],
            destination=serializer.validated_data["destination"],
        )
        return Response(
            RedemptionSerializer(redemption).data, status=status.HTTP_201_CREATED
        )


class RedemptionViewSet(viewsets.ModelViewSet):
    serializer_class = RedemptionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        if self.request.user.role in (User.Role.ADMIN,) or self.request.user.is_superuser:
            queryset = Redemption.objects.select_related("user", "handled_by")
        else:
            queryset = Redemption.objects.filter(user=self.request.user)
        search = self.request.query_params.get("q", "").strip()
        status_filter = self.request.query_params.get("status")
        if search:
            queryset = queryset.filter(
                Q(user__full_name__icontains=search)
                | Q(user__phone__icontains=search)
                | Q(method__icontains=search)
                | Q(destination__icontains=search)
                | Q(status__icontains=search)
            )
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        return queryset

    def create(self, request, *args, **kwargs):
        return Response(status=status.HTTP_405_METHOD_NOT_ALLOWED)

    @action(detail=True, methods=["post"], permission_classes=[IsAdmin])
    def approve(self, request, pk=None):
        redemption = self.get_object()
        if redemption.status != Redemption.Status.PENDING:
            return Response(
                {"detail": "Redemption already handled."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        redemption.status = Redemption.Status.PAID
        redemption.handled_by = request.user
        redemption.handled_at = timezone.now()
        redemption.save(update_fields=["status", "handled_by", "handled_at"])
        return Response(RedemptionSerializer(redemption).data)

    @action(detail=True, methods=["post"], permission_classes=[IsAdmin])
    def reject(self, request, pk=None):
        redemption = self.get_object()
        if redemption.status != Redemption.Status.PENDING:
            return Response(
                {"detail": "Redemption already handled."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        redemption.status = Redemption.Status.REJECTED
        redemption.note = request.data.get("reason", "")
        redemption.handled_by = request.user
        redemption.handled_at = timezone.now()
        redemption.save(
            update_fields=["status", "note", "handled_by", "handled_at"]
        )
        wallet = get_or_create_wallet(redemption.user)
        wallet.credit(
            redemption.amount,
            f"Refund for rejected redemption #{redemption.id}",
        )
        return Response(RedemptionSerializer(redemption).data)


class WalletStatsView(APIView):
    permission_classes = [IsAdmin]

    def get(self, request):
        credits = (
            WalletTransaction.objects.filter(kind=WalletTransaction.Kind.CREDIT)
            .aggregate(total=Sum("amount"))["total"]
            or 0
        )
        debits = (
            WalletTransaction.objects.filter(kind=WalletTransaction.Kind.DEBIT)
            .aggregate(total=Sum("amount"))["total"]
            or 0
        )
        pending = Redemption.objects.filter(status=Redemption.Status.PENDING).count()
        return Response(
            {
                "total_credited": str(credits),
                "total_paid_out": str(debits),
                "pending_redemptions": pending,
            }
        )
