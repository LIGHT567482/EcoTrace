const STATUS_COLORS = {
  PENDING: "#e5a11a",
  ASSIGNED: "#3478c5",
  COLLECTED: "#8057c7",
  IN_TRANSIT: "#16a6b6",
  RECEIVED: "#24a36b",
  PROCESSED: "#0c6b3f",
  REJECTED: "#dc4c4c",
  CANCELLED: "#748094",
  AVAILABLE: "#d66caa",
};

export const ACTIVITY_COLORS = [
  "#168a58",
  "#3478c5",
  "#8057c7",
  "#e5a11a",
  "#16a6b6",
  "#dc4c4c",
  "#d66caa",
];

export function getLastSevenDays(
  records,
  dateKey = "created_at",
  valueForRecord = () => 1,
) {
  const days = Array.from({ length: 7 }, (_, index) => {
    const date = new Date();
    date.setHours(0, 0, 0, 0);
    date.setDate(date.getDate() - (6 - index));
    return {
      date,
      label: date.toLocaleDateString(undefined, { weekday: "short" }),
      value: 0,
    };
  });
  const dayIndexes = new Map(
    days.map((day, index) => [day.date.toDateString(), index]),
  );

  records.forEach((record) => {
    if (!record[dateKey]) return;
    const date = new Date(record[dateKey]);
    if (Number.isNaN(date.getTime())) return;
    const index = dayIndexes.get(date.toDateString());
    if (index !== undefined) days[index].value += Number(valueForRecord(record)) || 0;
  });

  return days.map(({ label, value }) => ({ label, value }));
}

export function statusCounts(records, extra = []) {
  const statuses = [
    "PENDING",
    "ASSIGNED",
    "COLLECTED",
    "IN_TRANSIT",
    "RECEIVED",
    "PROCESSED",
    "REJECTED",
    "CANCELLED",
  ];
  return [
    ...statuses.map((status) => ({
      label: status.replaceAll("_", " "),
      value: records.filter((record) => record.status === status).length,
      color: STATUS_COLORS[status],
    })),
    ...extra,
  ];
}

export { STATUS_COLORS };
