import os

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.core.models import User
from apps.rewards.models import get_or_create_wallet
from apps.waste.models import Category, DropOffPoint, ItemType

# (type name, reward UGX, Carbon Dioxide equivalent avoided per unit, hazardous)
CATEGORIES = {
    "Phones": [
        ("Smartphone", 3000, 21.0, False),
        ("Feature phone", 1500, 8.0, False),
        ("Phone battery", 500, 1.5, True),
        ("Charger and cable", 300, 0.4, False),
    ],
    "Computers": [
        ("Laptop", 12000, 95.0, False),
        ("Desktop computer", 15000, 120.0, False),
        ("Monitor", 8000, 45.0, False),
        ("Keyboard or mouse", 500, 1.2, False),
        ("Computer battery", 1000, 2.0, True),
    ],
    "Televisions": [
        ("Flat screen TV", 20000, 80.0, False),
        ("CRT television", 25000, 130.0, True),
    ],
    "Batteries": [
        ("Rechargeable battery", 800, 1.8, True),
        ("Dry cell battery", 200, 0.3, True),
    ],
    "Appliances": [
        ("Radio", 2000, 6.0, False),
        ("Speaker", 1500, 5.0, False),
        ("Iron box", 3000, 12.0, False),
        ("Fridge or cooker", 25000, 150.0, True),
    ],
    "Cables and accessories": [
        ("Cables", 200, 0.2, False),
        ("Adapters", 400, 0.5, False),
    ],
}

DROP_OFF_POINTS = [
    ("Kansanga Market Collection Bay", "Kansanga trading centre, along Kabalagala road", "Kansanga", 0.3089, 32.6041, "+256700000001", "Mon-Sat 08:00-18:00"),
    ("Makindye Division Waste Yard", "Makindye Division offices", "Makindye", 0.3120, 32.5990, "+256700000002", "Mon-Fri 09:00-17:00"),
    ("Kampala WEEE Collection Centre", "Industrial area, Kampala", "Kampala", 0.3130, 32.5830, "+256700000003", "Mon-Sat 08:00-17:00"),
]

DEMO_ADMIN_PHONE = "+256761095861"
LEGACY_DEMO_ADMIN_PHONE = "+256700000010"

SEED_USERS = [
    ("+256700000011", "Jane Collector", User.Role.COLLECTOR, "Kansanga", "collect12345"),
    ("+256700000012", "Robert Recycler", User.Role.RECYCLER, "Kampala", "recycle12345"),
    ("+256700000013", "Mary Consumer", User.Role.CONSUMER, "Kansanga", "consumer12345"),
]


class Command(BaseCommand):
    help = "Seed EcoTrace with categories, drop-off points and demo accounts"

    @transaction.atomic
    def handle(self, *args, **options):
        admin_phone = os.environ.get("ECOTRACE_ADMIN_PHONE")
        admin_password = os.environ.get("ECOTRACE_ADMIN_PASSWORD")
        if settings.DEBUG:
            admin_phone = admin_phone or DEMO_ADMIN_PHONE
        if not admin_phone or not admin_password:
            raise CommandError(
                "Set ECOTRACE_ADMIN_PHONE and ECOTRACE_ADMIN_PASSWORD before "
                "seeding accounts."
            )

        if admin_phone != LEGACY_DEMO_ADMIN_PHONE:
            User.objects.filter(phone=LEGACY_DEMO_ADMIN_PHONE).update(is_active=False)

        for cat_name, types in CATEGORIES.items():
            category, _ = Category.objects.get_or_create(
                name=cat_name, defaults={"slug": cat_name.lower().replace(" ", "-")}
            )
            for type_name, reward, carbon_factor, hazardous in types:
                ItemType.objects.update_or_create(
                    category=category,
                    name=type_name,
                    defaults={
                        "reward_ugx": reward,
                        "points_per_item": reward,
                        "carbon_factor_kg": carbon_factor,
                        "hazardous": hazardous,
                        "is_active": True,
                    },
                )
        for name, address, town, lat, lng, phone, hours in DROP_OFF_POINTS:
            DropOffPoint.objects.get_or_create(
                name=name,
                defaults={
                    "address": address,
                    "town": town,
                    "latitude": lat,
                    "longitude": lng,
                    "phone": phone,
                    "opening_hours": hours,
                },
            )
        seed_users = [
            (
                admin_phone,
                "System Administrator",
                User.Role.ADMIN,
                "Kansanga",
                admin_password,
            ),
            *SEED_USERS,
        ]
        for phone, name, role, town, password in seed_users:
            user, _created = User.objects.get_or_create(
                phone=phone,
                defaults={
                    "full_name": name,
                    "role": role,
                    "town": town,
                    "is_staff": role == User.Role.ADMIN,
                },
            )
            # Seed accounts always keep their canonical role and password so
            # demo/admin logins survive redeploys and stray registrations.
            user.role = role
            user.is_active = True
            user.is_staff = role == User.Role.ADMIN
            user.set_password(password)
            user.save(
                update_fields=["role", "is_active", "is_staff", "password"]
            )
            get_or_create_wallet(user)
        self.stdout.write(
            self.style.SUCCESS(
                "Seeded: "
                f"{Category.objects.count()} categories, "
                f"{ItemType.objects.count()} item types, "
                f"{DropOffPoint.objects.count()} drop-off points, "
                f"{User.objects.count()} users."
            )
        )
