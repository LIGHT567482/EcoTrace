from django.contrib.sessions.models import Session
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.core.models import (
    AuditLog,
    Notification,
    StakeholderMessage,
    SuspendedSystemSetting,
    User,
)
from apps.rewards.models import (
    PointTransaction,
    Redemption,
    RewardPolicy,
    Wallet,
    WalletTransaction,
)
from apps.waste.models import (
    Category,
    Certificate,
    CollectionRequest,
    DropOffPoint,
    Item,
    ItemType,
    ProcessingRecord,
    RequestEvent,
)

# Children are cleared before their parents: item rows hold a protected
# reference to item types, so items have to go first.
PURGE_ORDER = (
    Notification,
    StakeholderMessage,
    AuditLog,
    SuspendedSystemSetting,
    RequestEvent,
    ProcessingRecord,
    Certificate,
    CollectionRequest,
    Item,
    DropOffPoint,
    ItemType,
    Category,
    Redemption,
    PointTransaction,
    WalletTransaction,
    Wallet,
    RewardPolicy,
    Session,
    User,
)


class Command(BaseCommand):
    help = (
        "Erase seeded and demo records so the system starts from a first run "
        "(fresh users can register and bootstrap_admin creates the first "
        "administrator)"
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--confirm",
            action="store_true",
            help="Confirm deletion of every application record",
        )

    @transaction.atomic
    def handle(self, *args, **options):
        if not options["confirm"]:
            raise CommandError(
                "This removes every user, request, item, reward and catalogue "
                "record. Review the scope and rerun with --confirm."
            )

        cleared = []
        for model in PURGE_ORDER:
            deleted, _ = model.objects.all().delete()
            if deleted:
                cleared.append(f"{model._meta.label}: {deleted}")

        if cleared:
            for line in cleared:
                self.stdout.write(f"  cleared {line}")
        else:
            self.stdout.write("  nothing to clear")

        self.stdout.write(
            self.style.SUCCESS(
                "Seed data purged. The database is in a first-run state; run "
                "bootstrap_admin to create the first administrator."
            )
        )
