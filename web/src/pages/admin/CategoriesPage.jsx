import { useEffect, useState } from "react";
import { api } from "../../api";

export default function CategoriesPage() {
  const [categories, setCategories] = useState([]);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [categoryName, setCategoryName] = useState("");
  const [categoryBusy, setCategoryBusy] = useState(false);
  const [form, setForm] = useState({
    category: "",
    name: "",
    points_per_item: 1000,
  });

  function load() {
    const query = new URLSearchParams();
    if (search.trim()) query.set("q", search.trim());
    api(`/categories/?${query}`)
      .then((d) => {
        const list = d.results || d;
        setCategories(list);
        setForm((f) => ({
          ...f,
          category: list.some((category) => String(category.id) === String(f.category))
            ? f.category
            : list[0]?.id || "",
        }));
      })
      .catch((e) => setError(e.message));
  }

  useEffect(load, [search]);

  async function addCategory(event) {
    event.preventDefault();
    setError("");
    setCategoryBusy(true);
    try {
      await api("/categories/", {
        method: "POST",
        body: { name: categoryName.trim() },
      });
      setCategoryName("");
      load();
    } catch (err) {
      setError(
        err.data && typeof err.data === "object"
          ? Object.values(err.data).flat().join(" ")
          : err.message,
      );
    } finally {
      setCategoryBusy(false);
    }
  }

  async function add(e) {
    e.preventDefault();
    setError("");
    try {
      await api("/item-types/", {
        method: "POST",
        body: {
          category: Number(form.category),
          name: form.name,
          points_per_item: Number(form.points_per_item),
        },
      });
      setForm({ ...form, name: "" });
      load();
    } catch (err) {
      setError(
        err.data && typeof err.data === "object"
          ? Object.values(err.data).flat().join(" ")
          : err.message
      );
    }
  }

  async function toggleActive(t) {
    if (
      t.is_active &&
      !window.confirm(
        `Disable ${t.name}? It will stop earning rewards until re-enabled.`
      )
    )
      return;
    setError("");
    try {
      await api(`/item-types/${t.id}/`, {
        method: "PATCH",
        body: { is_active: !t.is_active },
      });
      load();
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Categories & item types</h1>
          <p>Item types and reward values used across the system.</p>
        </div>
      </div>
      {error && <div className="alert error">{error}</div>}

      <div className="card" style={{ marginBottom: "1rem" }}>
        <h3>Add category</h3>
        <form className="form row" onSubmit={addCategory}>
          <label className="field">
            Category name
            <input
              value={categoryName}
              onChange={(event) => setCategoryName(event.target.value)}
              required
              maxLength={100}
            />
          </label>
          <button className="btn" disabled={categoryBusy || !categoryName.trim()}>
            {categoryBusy ? "Saving…" : "Add category"}
          </button>
        </form>
      </div>

      <div className="card" style={{ marginBottom: "1rem" }}>
        <h3>Add item type</h3>
        <form className="form row" onSubmit={add}>
          <label className="field">
            Category
            <select
              value={form.category}
              onChange={(e) => setForm({ ...form, category: e.target.value })}
            >
              {categories.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            Name
            <input
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              required
            />
          </label>
          <label className="field">
            Points per item
            <input
              type="number"
              min="0"
              step="1"
              value={form.points_per_item}
              onChange={(e) => setForm({ ...form, points_per_item: e.target.value })}
            />
          </label>
          <button className="btn" disabled={!form.category}>
            Add
          </button>
        </form>
      </div>

      <label className="field" style={{ marginBottom: "1rem" }}>
        Search categories and item types
        <input
          type="search"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="Search by category or item type"
        />
      </label>

      <div className="grid cols-2">
        {categories.map((c) => (
          <div className="card" key={c.id}>
            <h3>{c.name}</h3>
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Type</th>
                    <th>Points / item</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  {c.types.map((t) => (
                    <tr key={t.id} style={{ opacity: t.is_active ? 1 : 0.5 }}>
                      <td>{t.name}</td>
                      <td>{Number(t.points_per_item).toLocaleString()} pts</td>
                      <td>
                        <button
                          className="btn ghost small"
                          onClick={() => toggleActive(t)}
                        >
                          {t.is_active ? "Disable" : "Enable"}
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
