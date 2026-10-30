"use client";
import { useEffect, useRef, useState, type FormEvent } from "react";
export type Values = Record<string, string | boolean | string[]>;
export type Option = { value: string; label: string };
export type Field = {
  key: string;
  label: string;
  type?:
    | "text"
    | "number"
    | "textarea"
    | "checkbox"
    | "select"
    | "date"
    | "datetime-local"
    | "time"
    | "multi";
  options?: Option[];
  required?: boolean;
  help?: string;
  min?: number;
  max?: number;
  step?: number;
  initial?: string | boolean | string[];
};
export function AdminForm({
  title,
  fields,
  save,
  cancel,
  initial = {},
  submit = "ذخیره تغییرات",
}: {
  title: string;
  fields: Field[];
  save: (values: Values, key: string) => Promise<void>;
  cancel: () => void;
  initial?: Values;
  submit?: string;
}) {
  const [values, setValues] = useState<Values>(() =>
      Object.fromEntries(
        fields.map((f) => [
          f.key,
          initial[f.key] ??
            f.initial ??
            (f.type === "checkbox" ? false : f.type === "multi" ? [] : ""),
        ]),
      ),
    ),
    [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  const region = useRef<HTMLElement>(null),
    err = useRef<HTMLDivElement>(null),
    intent = useRef<{ data: string; key: string } | undefined>(undefined);
  useEffect(() => {
    region.current?.scrollIntoView({ block: "nearest" });
    region.current
      ?.querySelector<HTMLInputElement>("input,select,textarea")
      ?.focus();
  }, []);
  const change = (key: string, value: Values[string]) =>
    setValues((v) => ({ ...v, [key]: value }));
  async function submitForm(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError("");
    const data = JSON.stringify(values);
    if (intent.current?.data !== data)
      intent.current = { data, key: crypto.randomUUID() };
    try {
      await save(values, intent.current!.key);
      cancel();
    } catch (e) {
      setError((e as Error).message);
      requestAnimationFrame(() => err.current?.focus());
    } finally {
      setBusy(false);
    }
  }
  return (
    <section ref={region} className="admin-editor" aria-label={title}>
      <div className="admin-section-head">
        <h2>{title}</h2>
        <button
          type="button"
          className="admin-button"
          onClick={cancel}
          disabled={busy}
        >
          بستن فرم
        </button>
      </div>
      <form onSubmit={submitForm}>
        {error && (
          <div ref={err} role="alert" tabIndex={-1} className="admin-error">
            {error}
          </div>
        )}
        <div className="admin-form-grid">
          {fields.map((f) => {
            const id = "admin-field-" + f.key,
              value = values[f.key];
            return (
              <div
                key={f.key}
                className={
                  f.type === "textarea" || f.type === "multi"
                    ? "admin-field admin-wide"
                    : "admin-field"
                }
              >
                {f.type === "checkbox" ? (
                  <label className="admin-check">
                    <input
                      id={id}
                      type="checkbox"
                      checked={value === true}
                      required={f.required}
                      disabled={busy}
                      onChange={(e) => change(f.key, e.target.checked)}
                    />
                    <span>{f.label}</span>
                  </label>
                ) : (
                  <>
                    <label htmlFor={id}>
                      {f.label}
                      {f.required !== false && (
                        <span aria-hidden="true"> *</span>
                      )}
                    </label>
                    {f.type === "textarea" ? (
                      <textarea
                        id={id}
                        required={f.required !== false}
                        value={String(value ?? "")}
                        disabled={busy}
                        rows={4}
                        onChange={(e) => change(f.key, e.target.value)}
                      />
                    ) : f.type === "select" ? (
                      <select
                        id={id}
                        required={f.required !== false}
                        value={String(value ?? "")}
                        disabled={busy}
                        onChange={(e) => change(f.key, e.target.value)}
                      >
                        <option value="">انتخاب کنید</option>
                        {f.options?.map((o) => (
                          <option key={o.value} value={o.value}>
                            {o.label}
                          </option>
                        ))}
                      </select>
                    ) : f.type === "multi" ? (
                      <fieldset id={id}>
                        <legend className="sr-only">{f.label}</legend>
                        {f.options?.length ? (
                          f.options.map((o) => (
                            <label key={o.value} className="admin-check">
                              <input
                                type="checkbox"
                                checked={
                                  Array.isArray(value) &&
                                  value.includes(o.value)
                                }
                                disabled={busy}
                                onChange={(e) =>
                                  change(
                                    f.key,
                                    e.target.checked
                                      ? [
                                          ...(Array.isArray(value)
                                            ? value
                                            : []),
                                          o.value,
                                        ]
                                      : (Array.isArray(value)
                                          ? value
                                          : []
                                        ).filter((x) => x !== o.value),
                                  )
                                }
                              />
                              {o.label}
                            </label>
                          ))
                        ) : (
                          <p className="admin-muted">گزینه‌ای ثبت نشده است.</p>
                        )}
                      </fieldset>
                    ) : (
                      <input
                        id={id}
                        type={f.type ?? "text"}
                        value={String(value ?? "")}
                        disabled={busy}
                        required={f.required !== false}
                        min={f.min}
                        max={f.max}
                        step={f.step}
                        inputMode={f.type === "number" ? "numeric" : undefined}
                        onChange={(e) => change(f.key, e.target.value)}
                      />
                    )}
                  </>
                )}
                {f.help && <small className="admin-muted">{f.help}</small>}
              </div>
            );
          })}
        </div>
        <div className="admin-form-actions">
          <button
            className="admin-button admin-primary"
            disabled={busy}
            type="submit"
          >
            {busy ? "در حال ثبت…" : submit}
          </button>
          <span role="status" className="admin-muted">
            {busy
              ? "تا مشخص شدن نتیجه، این فرم را دوباره باز نکنید."
              : "اطلاعات فقط پس از تأیید سرور ذخیره می‌شوند."}
          </span>
        </div>
      </form>
    </section>
  );
}
