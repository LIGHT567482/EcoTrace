import { useEffect, useState } from "react";
import { api, formatDate } from "../api";
import { useAuth } from "../auth";

export default function MessagesPage() {
  const { user } = useAuth();
  const [contacts, setContacts] = useState([]);
  const [contactId, setContactId] = useState("");
  const [messages, setMessages] = useState([]);
  const [body, setBody] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    api("/messages/contacts/")
      .then((list) => {
        setContacts(list);
        setContactId((current) => current || String(list[0]?.id || ""));
      })
      .catch((e) => setError(e.message));
  }, []);

  useEffect(() => {
    if (!contactId) return undefined;
    let active = true;
    const load = () =>
      api(`/messages/?with=${contactId}`)
        .then((data) => {
          if (active) setMessages(data.results || []);
        })
        .catch((e) => {
          if (active) setError(e.message);
        });
    load();
    const timer = window.setInterval(load, 20000);
    return () => {
      active = false;
      window.clearInterval(timer);
    };
  }, [contactId]);

  async function send(event) {
    event.preventDefault();
    if (!contactId || !body.trim()) return;
    setError("");
    setBusy(true);
    try {
      const message = await api("/messages/", {
        method: "POST",
        body: { recipient_id: Number(contactId), body: body.trim() },
      });
      setMessages((current) => [...current, message]);
      setBody("");
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  const selectedContact = contacts.find((contact) => String(contact.id) === contactId);

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Stakeholder messages</h1>
          <p>Message the next role in your EcoTrace workflow.</p>
        </div>
        <label className="field">
          Recipient
          <select value={contactId} onChange={(event) => setContactId(event.target.value)}>
            {contacts.map((contact) => (
              <option key={contact.id} value={contact.id}>
                {contact.full_name || contact.phone} · {contact.role} · {contact.town}
              </option>
            ))}
          </select>
        </label>
      </div>
      {error && <div className="alert error">{error}</div>}
      <section className="card message-panel">
        <div className="message-panel-head">
          <strong>
            {selectedContact
              ? `${selectedContact.full_name || selectedContact.phone} · ${selectedContact.role}`
              : "No available contacts"}
          </strong>
          {selectedContact && <small>{selectedContact.town}</small>}
        </div>
        <div className="message-thread" aria-live="polite">
          {messages.map((message) => {
            const outgoing = message.sender === user.id;
            return (
              <article
                className={`message-bubble${outgoing ? " outgoing" : " incoming"}`}
                key={message.id}
              >
                <p>{message.body}</p>
                <small>{formatDate(message.created_at)}</small>
              </article>
            );
          })}
          {!messages.length && selectedContact && (
            <p className="empty">No messages with this stakeholder yet.</p>
          )}
          {!contacts.length && <p className="empty">No eligible stakeholders are available.</p>}
        </div>
        <form className="form message-compose" onSubmit={send}>
          <label className="field">
            Message
            <textarea
              value={body}
              onChange={(event) => setBody(event.target.value)}
              maxLength={2000}
              rows={3}
              required
              disabled={!contactId || busy}
            />
          </label>
          <button className="btn" disabled={!contactId || !body.trim() || busy}>
            {busy ? "Sending…" : "Send message"}
          </button>
        </form>
      </section>
    </div>
  );
}