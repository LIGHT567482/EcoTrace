import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../../api";

export default function ItemsPage() {
  const [categories, setCategories] = useState([]);
  const [items, setItems] = useState([]);
  const [search, setSearch] = useState("");
  const [error, setError] = useState("");
  const [form, setForm] = useState({
    category: "",
    item_type: "",
    quantity: 1,
    condition: "BROKEN",
    notes: "",
  });
  const [saving, setSaving] = useState(false);

  const loadItems = useCallback(() => {
    const query = new URLSearchParams();
    if (search.trim()) query.set("q", search.trim());
    api(`/items/?${query}`)
      .then((d) => setItems(d.results || d))
      .catch((e) => setError(e.message));
  }, [search]);

  useEffect(() => {
    api("/categories/")
      .then((d) => {
        const list = d.results || d;
        setCategories(list);
        if (list[0]) {
          setForm((f) => ({
            ...f,
            category: list[0].id,
            item_type: list[0].types[0]?.id || "",
          }));
        }
      })
      .catch((e) => setError(e.message));
  }, []);

  useEffect(loadItems, [loadItems]);

  const selectedCategory = categories.find((c) => String(c.id) === String(form.category));

  async function submit(e) {
    e.preventDefault();
    setSaving(true);
    setError("");
    try {
      await api("/items/", {
        method: "POST",
        body: {
          item_type: Number(form.item_type),
          quantity: Number(form.quantity),
          condition: form.condition,
          notes: form.notes,
        },
      });
      setForm((f) => ({ ...f, quantity: 1, notes: "" }));
      loadItems();
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  }

  async function remove(id) {
    setError("");
    try {
      await api(`/items/${id}/`, { method: "DELETE" });
      loadItems();
    } catch (err) {
      setError(err.message || "Cannot delete this item.");
    }
  }

  const totalReward = items.reduce((s, i) => s + Number(i.points || 0), 0);

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Log your e-waste</h1>
          <p>Add every item you want to dispose of, then request a pickup.</p>
        </div>
        <Link className="btn" to="/requests/new">
          Request pickup
        </Link>
      </div>
      {error && <div className="alert error">{error}</div>}

      <div className="grid cols-2">
        <div className="card">
          <h3>New item</h3>
          <form className="form" onSubmit={submit}>
            <label className="field">
              Category
              <select
                value={form.category}
                onChange={(e) => {
                  const cat = categories.find((c) => String(c.id) === e.target.value);
                  setForm({
                    ...form,
                    category: e.target.value,
                    item_type: cat?.types[0]?.id || "",
                  });
                }}
              >
                {categories.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </label>
            <label className="field">
              Type
              <select
                value={form.item_type}
                onChange={(e) => setForm({ ...form, item_type: e.target.value })}
              >
                {(selectedCategory?.types || []).map((t) => (
                  <option key={t.id} value={t.id}>
                    {t.name} - {Number(t.points_per_item).toLocaleString()} base points
                  </option>
                ))}
              </select>
            </label>
            <div className="form row">
              <label className="field">
                Quantity
                <input
                  type="number"
                  min="1"
                  value={form.quantity}
                  onChange={(e) => setForm({ ...form, quantity: e.target.value })}
                  required
                />
              </label>
              <label className="field">
                Condition
                <select
                  value={form.condition}
                  onChange={(e) => setForm({ ...form, condition: e.target.value })}
                >
                  <option value="WORKING">Working</option>
                  <option value="BROKEN">Broken</option>
                  <option value="DAMAGED">Damaged / hazardous</option>
                </select>
              </label>
            </div>
            <label className="field">
              Notes (optional)
              <input
                value={form.notes}
                onChange={(e) => setForm({ ...form, notes: e.target.value })}
                placeholder="e.g. cracked screen, includes charger"
              />
            </label>
            <button className="btn" disabled={saving || !form.item_type}>
              {saving ? "Saving…" : "Add item"}
            </button>
          </form>
        </div>

        <div className="card">
          <h3>Your logged items</h3>
          <label className="field mt">
            Search logged items
            <input
              type="search"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Item type, category, or note"
            />
          </label>
          <div>
            <div className="stat">{items.length}</div>
            <div className="sub">item rows</div>
          </div>
          <p className="sub mt">Potential points at drop-off: {Math.round(totalReward).toLocaleString()} pts</p>
          <div className="grid mt" style={{ gap: "0.5rem" }}>
            {items.map((it) => (
              <div className="item-row" key={it.id}>
                <div>
                  <strong>{it.type_name}</strong>
                  <br />
                  <small>
                    {it.category_name} · qty {it.quantity} · {it.condition}
                  </small>
                </div>
                <div className="right">
                  <small>{Number(it.points).toLocaleString()} base pts</small>
                  <br />
                  <button className="btn ghost small" onClick={() => remove(it.id)}>
                    Remove
                  </button>
                </div>
              </div>
            ))}
            {!items.length && <div className="empty">Nothing logged yet.</div>}
          </div>
        </div>
      </div>
    </div>
  );
}
