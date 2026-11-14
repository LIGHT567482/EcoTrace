from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.core.models import User
from apps.waste.models import (
    Category,
    CollectionRequest,
    Item,
    ItemType,
    RequestEvent,
)

DEMO_MARKER = "DEMO DATA:"
PHONE_PREFIX = "+256700900"
ACTIVITY_TYPES = (
    ("Demo laptop", 1000, 1000, 20.0),
    ("Demo mobile phone", 500, 500, 8.0),
    ("Demo small appliance", 750, 750, 12.0),
)


class Command(BaseCommand):
    help = "Create clearly marked demo consumer accounts and inactive sample requests"

    def add_arguments(self, parser):
        parser.add_argument(
            "--users",
            type=int,
            default=3,
            help="Number of demo consumer accounts to ensure (default: 3)",
        )
        parser.add_argument(
            "--activities-per-user",
            type=int,
            default=3,
            help="Minimum number of demo requests per account (default: 3; minimum: 3)",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Report what would be created without changing the database",
        )

    @transaction.atomic
    def handle(self, *args, **options):
        users_count = options["users"]
        activities_per_user = options["activities_per_user"]
        dry_run = options["dry_run"]

        if users_count < 1:
            raise CommandError("--users must be at least 1.")
        if activities_per_user < 3:
            raise CommandError("--activities-per-user must be at least 3.")

        seed_users = []
        for index in range(1, users_count + 1):
            phone = f"{PHONE_PREFIX}{index:03d}"
            full_name = f"EcoTrace Demo Consumer {index:03d}"
            user = User.objects.filter(phone=phone).first()

            if user and (
                user.role != User.Role.CONSUMER or user.full_name != full_name
            ):
                raise CommandError(
                    f"Phone {phone} is already assigned to a non-demo account. "
                    "No data was changed."
                )

            existing_activities = (
                CollectionRequest.objects.filter(
                    consumer=user,
                    consumer_note__startswith=DEMO_MARKER,
                ).count()
                if user
                else 0
            )
            to_create = max(0, activities_per_user - existing_activities)
            seed_users.append((index, phone, full_name, user, to_create))

        if dry_run:
            for index, phone, full_name, user, to_create in seed_users:
                account_action = "reuse" if user else "create"
                self.stdout.write(
                    f"Would {account_action} {full_name} ({phone}); "
                    f"add {to_create} demo request(s)."
                )
            return

        category, _ = Category.objects.get_or_create(
            slug="ecotrace-demo-electronics",
            defaults={"name": "EcoTrace Demo Electronics"},
        )
        if category.name != "EcoTrace Demo Electronics":
            raise CommandError(
                "The ecotrace-demo-electronics category slug is already in use "
                "by another category. No data was changed."
            )

        item_types = [
            ItemType.objects.get_or_create(
                category=category,
                name=name,
                defaults={
                    "points_per_item": points,
                    "reward_ugx": reward,
                    "carbon_factor_kg": carbon,
                },
            )[0]
            for name, points, reward, carbon in ACTIVITY_TYPES
        ]

        for index, phone, full_name, user, to_create in seed_users:
            if user is None:
                user = User.objects.create_user(
                    phone=phone,
                    full_name=full_name,
                    role=User.Role.CONSUMER,
                    town="Kansanga",
                    address=f"Demo address {index}, Kansanga",
                )
                self.stdout.write(f"Created demo account {phone}.")
            else:
                self.stdout.write(f"Reusing demo account {phone}.")

            starting_activity = CollectionRequest.objects.filter(
                consumer=user,
                consumer_note__startswith=DEMO_MARKER,
            ).count()
            for offset in range(to_create):
                activity_number = starting_activity + offset + 1
                item_type = item_types[(activity_number - 1) % len(item_types)]
                item = Item.objects.create(
                    consumer=user,
                    item_type=item_type,
                    quantity=1,
                    condition=Item.Condition.BROKEN,
                    notes=f"{DEMO_MARKER} sample item",
                )
                request = CollectionRequest.objects.create(
                    consumer=user,
                    request_type=CollectionRequest.Type.PICKUP,
                    status=CollectionRequest.Status.CANCELLED,
                    pickup_address=user.address,
                    consumer_note=(
                        f"{DEMO_MARKER} synthetic sample activity "
                        f"{activity_number}; not a real collection."
                    ),
                )
                request.items.add(item)
                RequestEvent.objects.create(
                    request=request,
                    status=CollectionRequest.Status.CANCELLED,
                    note=f"{DEMO_MARKER} synthetic request; no collection scheduled.",
                    actor=user,
                )

            self.stdout.write(
                f"Ensured at least {activities_per_user} demo requests "
                f"for {phone}."
            )

        self.stdout.write(self.style.SUCCESS("Demo data seeding complete."))
