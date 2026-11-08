import os

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.core.models import User


class Command(BaseCommand):
    help = "Create the configured administrator on first run"

    @transaction.atomic
    def handle(self, *args, **options):
        phone = os.environ.get("ECOTRACE_ADMIN_PHONE", "").strip()
        password = os.environ.get("ECOTRACE_ADMIN_PASSWORD", "")

        if not phone or not password:
            raise CommandError(
                "Set ECOTRACE_ADMIN_PHONE and ECOTRACE_ADMIN_PASSWORD before "
                "bootstrapping the administrator."
            )

        user = User.objects.filter(phone=phone).first()
        if user is not None:
            if user.role != User.Role.ADMIN and not user.is_superuser:
                raise CommandError(
                    "ECOTRACE_ADMIN_PHONE belongs to a non-administrator account. "
                    "Choose a phone number that is not already registered."
                )
            restored = []
            if not user.is_active:
                user.is_active = True
                restored.append("is_active")
            if not user.is_staff:
                user.is_staff = True
                restored.append("is_staff")
            if not user.is_superuser:
                user.is_superuser = True
                restored.append("is_superuser")
            if user.role != User.Role.ADMIN:
                user.role = User.Role.ADMIN
                restored.append("role")
            if restored:
                user.save(update_fields=restored)
                self.stdout.write(
                    self.style.SUCCESS(
                        "Administrator already exists; restored access ("
                        + ", ".join(restored)
                        + ")."
                    )
                )
            else:
                self.stdout.write(
                    "Administrator already exists; credentials unchanged."
                )
            return

        User.objects.create_superuser(
            phone=phone,
            password=password,
            full_name="System Administrator",
        )
        self.stdout.write(self.style.SUCCESS("Created the first administrator."))
