from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="notification",
            name="request_id",
            field=models.PositiveIntegerField(blank=True, null=True),
        ),
    ]
