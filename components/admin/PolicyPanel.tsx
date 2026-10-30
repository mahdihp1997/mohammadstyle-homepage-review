"use client";
import { useRef, useState, type FormEvent } from "react";
import type { Editor } from "./types";
import {
  api,
  query,
  pageItems,
  text,
  name,
  money,
  statuses,
  type Row,
  type Page,
} from "@/lib/mvp/client";
const hundred = BigInt(100);
const percent = (bps: unknown) => {
  try {
    if (!/^(0|[1-9][0-9]*)$/.test(text(bps))) return "";
    const n = BigInt(text(bps));
    return (
      String(n / hundred) +
      (n % hundred
        ? "." +
          String(n % hundred)
            .padStart(2, "0")
            .replace(/0+$/, "")
        : "")
    );
  } catch {
    return "";
  }
};
function bps(value: string) {
  if (!/^(?:0|[1-9]\d?)(?:\.\d{1,2})?$|^100(?:\.0{1,2})?$/.test(value))
    throw Error("درصد را بین صفر و ۱۰۰، با حداکثر دو رقم اعشار، وارد کنید.");
  const [a, b = ""] = value.split(".");
  return String(BigInt(a) * hundred + BigInt(b.padEnd(2, "0")));
}
function localInput(iso: unknown, zone: string) {
  if (!iso) return "";
  try {
    const p = new Intl.DateTimeFormat("en-CA", {
        timeZone: zone,
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
        hourCycle: "h23",
      }).formatToParts(new Date(text(iso))),
      v = (k: string) => p.find((x) => x.type === k)!.value;
    return (
      v("year") +
      "-" +
      v("month") +
      "-" +
      v("day") +
      "T" +
      v("hour") +
      ":" +
      v("minute")
    );
  } catch {
    return "";
  }
}
export default function PolicyPanel({
  data,
  branch,
  zone,
  services,
  staff,
  can,
  open,
  notify,
}: {
  data: Record<string, Page>;
  branch: string | null;
  zone: string;
  services: Row[];
  staff: Row[];
  can: (p: string, b?: string | null) => boolean;
  open: (e: Editor) => void;
  notify: () => void;
}) {
  const [editing, setEditing] = useState<{ parent: Row; version?: Row }>(),
    policies = pageItems(data.pricingPolicies),
    headers = pageItems(data.policyHeaders),
    assignments = pageItems(data.pricingAssignments),
    version = text(data.pricingContext?.version) || "1";
  async function command(
    op: string,
    id: string | null,
    payload: unknown,
    key: string,
    scope: string | null = branch,
  ) {
    await api("admin/pricing/commands/" + op, {
      method: "POST",
      key,
      version,
      data: { branchId: scope, entityId: id, data: payload },
    });
    notify();
  }
  async function instant(value: unknown) {
    return text(
      (
        await api<{ instant: string }>(
          "admin/portal/read/instant" +
            query({ branchId: branch, local: value }),
        )
      ).instant,
    );
  }
  function header() {
    setEditing(undefined);
    open({
      title: "افزودن سیاست",
      fields: [
        { key: "code", label: "کد سیاست" },
        { key: "name", label: "نام سیاست" },
        {
          key: "scope",
          label: "محدودهٔ سیاست",
          type: "select",
          options: [
            { value: "BRANCH", label: "شعبهٔ انتخاب‌شده" },
            ...(can("policy.manage", null)
              ? [{ value: "BUSINESS", label: "کل مجموعه" }]
              : []),
          ],
        },
      ],
      save: async (v, k) => {
        await command(
          "policy.create",
          null,
          { code: v.code, name: v.name },
          k,
          v.scope === "BUSINESS" ? null : branch,
        );
      },
    });
  }
  function lifecycle(p: Row, op: "version.publish" | "version.retire") {
    setEditing(undefined);
    open({
      title:
        op === "version.publish"
          ? "فعال‌سازی نسخهٔ سیاست"
          : "بازنشسته کردن نسخه",
      fields: [
        {
          key: "confirmed",
          label:
            op === "version.publish"
              ? "تمام شرایط را بررسی کرده‌ام؛ نسخهٔ فعال قابل ویرایش نیست."
              : "استفادهٔ جدید از این نسخه متوقف شود؛ شرایط رزروهای پذیرفته‌شده حفظ می‌شود.",
          type: "checkbox",
          required: true,
        },
      ],
      submit: op === "version.publish" ? "فعال‌سازی نسخه" : "بازنشسته کردن",
      save: async (_v, k) => {
        await command(
          op,
          p.id,
          {},
          k,
          p.branchId === null ? null : text(p.branchId),
        );
      },
    });
  }
  function assignment() {
    setEditing(undefined);
    open({
      title: "اعمال نسخهٔ سیاست",
      fields: [
        {
          key: "versionId",
          label: "نسخهٔ فعال",
          type: "select",
          options: policies
            .filter((p) => p.lifecycle === "ACTIVE")
            .map((p) => ({
              value: p.id,
              label: text(p.name) + " · نسخه " + text(p.versionNumber),
            })),
        },
        {
          key: "scopeKind",
          label: "محدودهٔ اعمال",
          type: "select",
          options: [
            { value: "BRANCH", label: "این شعبه" },
            { value: "SERVICE", label: "خدمت در این شعبه" },
            { value: "STAFF", label: "عضو تیم در این شعبه" },
            ...(can("policy.manage", null)
              ? [{ value: "BUSINESS", label: "کل مجموعه" }]
              : []),
          ],
        },
        {
          key: "serviceId",
          label: "خدمت؛ فقط برای محدودهٔ خدمت",
          type: "select",
          required: false,
          options: services.map((s) => ({ value: s.id, label: name(s) })),
        },
        {
          key: "staffId",
          label: "عضو تیم؛ فقط برای محدودهٔ عضو",
          type: "select",
          required: false,
          options: staff.map((s) => ({ value: s.id, label: name(s) })),
        },
        {
          key: "priority",
          label: "اولویت (عدد صحیح ۰ تا ۱۰۰۰)",
          type: "number",
          min: 0,
          max: 1000,
        },
        {
          key: "effectiveFrom",
          label: "شروع اعتبار به وقت شعبه",
          type: "datetime-local",
        },
        {
          key: "effectiveTo",
          label: "پایان اعتبار به وقت شعبه (اختیاری)",
          type: "datetime-local",
          required: false,
        },
      ],
      save: async (v, k) => {
        await command(
          "assignment.create",
          null,
          {
            versionId: v.versionId,
            scopeKind: v.scopeKind,
            serviceId: v.scopeKind === "SERVICE" ? v.serviceId || null : null,
            staffId: v.scopeKind === "STAFF" ? v.staffId || null : null,
            priority: text(v.priority),
            effectiveFrom: await instant(v.effectiveFrom),
            effectiveTo: v.effectiveTo ? await instant(v.effectiveTo) : null,
            reason: null,
            serviceIds: [],
            compatibleVersionIds: [],
          },
          k,
          v.scopeKind === "BUSINESS" ? null : branch,
        );
      },
    });
  }
  return (
    <>
      <section className="admin-panel">
        <div className="admin-section-head">
          <h2>سیاست‌های نسخه‌دار</h2>
          {can("policy.manage") && (
            <button className="admin-button admin-primary" onClick={header}>
              افزودن سیاست
            </button>
          )}
        </div>
        <p>
          مبلغ و شرایط واقعی را فقط پس از تأیید وارد کنید. تغییر سیاست، متن یا
          مبلغِ پذیرفته‌شده در رزروهای قبلی را عوض نمی‌کند.
        </p>
        <p className="admin-muted">
          سیاست‌های ناسازگار برای چند خدمت، بدون تصمیم صریح و پیکربندی تأییدشده،
          مانع رزرو می‌شوند.
        </p>
        <div className="admin-category-list">
          {headers.map((p) => (
            <div key={p.id}>
              <span>{text(p.name)}</span>
              {can(
                "policy.manage",
                p.branchId === null ? null : text(p.branchId),
              ) && (
                <button
                  className="admin-button"
                  onClick={() => setEditing({ parent: p })}
                >
                  نسخهٔ جدید
                </button>
              )}
            </div>
          ))}
        </div>
        {!headers.length && (
          <div className="admin-empty">
            سیاستی ثبت نشده است. ابتدا عنوان سیاست و سپس نسخهٔ شرایط آن را وارد
            کنید.
          </div>
        )}
      </section>
      {editing && (
        <PolicyEditor
          parent={editing.parent}
          versionRow={editing.version}
          zone={zone}
          branch={branch}
          cancel={() => setEditing(undefined)}
          save={async (terms, key) => {
            await command(
              editing.version ? "version.replace" : "version.create",
              editing.version?.id ?? editing.parent.id,
              { terms },
              key,
              editing.parent.branchId === null
                ? null
                : text(editing.parent.branchId),
            );
            setEditing(undefined);
          }}
        />
      )}
      <section className="admin-panel">
        <h2>نسخه‌ها و شرایط</h2>
        <div className="admin-record-grid">
          {policies.map((p) => {
            const t = p.terms as Record<string, unknown>;
            return (
              <article key={p.id} className="admin-record">
                <div className="admin-section-head">
                  <h3>
                    {text(p.name)} · نسخه {text(p.versionNumber)}
                  </h3>
                  <span className="admin-tag">
                    {statuses[text(p.lifecycle)] ?? text(p.lifecycle)}
                  </span>
                </div>
                <dl>
                  <dt>بیعانه</dt>
                  <dd>
                    {t.depositRequirement === "NONE"
                      ? "بدون بیعانه"
                      : t.depositRequirement === "OPTIONAL"
                        ? "اختیاری"
                        : "الزامی"}
                  </dd>
                  <dt>مبلغ</dt>
                  <dd>
                    {t.amountKind === "FIXED"
                      ? money(t.fixedRial)
                      : t.amountKind === "PERCENTAGE"
                        ? percent(t.basisPoints) + "٪"
                        : "—"}
                  </dd>
                  <dt>مهلت لغو</dt>
                  <dd>
                    {text(t.cancellationDeadlineMinutes)} دقیقه پیش از شروع
                  </dd>
                </dl>
                <details>
                  <summary>مشاهدهٔ شرایط کامل</summary>
                  <p className="admin-policy-text">{text(t.termsText)}</p>
                  <dl>
                    <dt>قابلیت بازپرداخت</dt>
                    <dd>
                      {
                        (
                          {
                            FULL: "کامل",
                            NONE: "بدون بازپرداخت",
                            PARTIAL: "بخشی",
                            CONDITIONAL: "شرطی",
                          } as Record<string, string>
                        )[text(t.refundability)]
                      }
                    </dd>
                    <dt>مبنای بازپرداخت</dt>
                    <dd>
                      {t.refundBase === "DEPOSIT_PAID"
                        ? "بیعانهٔ پرداخت‌شده"
                        : "تمام مبلغ پرداخت‌شده"}
                    </dd>
                    <dt>نرخ خارج از بازه‌ها</dt>
                    <dd>{percent(t.outsideRefundBps)}٪</dd>
                    <dt>حداقل / حداکثر بیعانه</dt>
                    <dd>
                      {t.minimumRial === null
                        ? "بدون حداقل ثبت‌شده"
                        : money(t.minimumRial)}{" "}
                      /{" "}
                      {t.maximumRial === null
                        ? "بدون حداکثر ثبت‌شده"
                        : money(t.maximumRial)}
                    </dd>
                  </dl>
                  {(
                    (t.refundWindows as {
                      thresholdMinutes: string;
                      refundBps: string;
                    }[]) ?? []
                  ).map((w) => (
                    <p key={w.thresholdMinutes}>
                      {w.thresholdMinutes} دقیقه پیش از شروع:{" "}
                      {percent(w.refundBps)}٪
                    </p>
                  ))}
                </details>
                {can(
                  "policy.manage",
                  p.branchId === null ? null : text(p.branchId),
                ) && (
                  <div className="admin-row-actions">
                    {p.lifecycle === "DRAFT" && (
                      <>
                        <button
                          className="admin-button"
                          onClick={() =>
                            setEditing({
                              parent: headers.find(
                                (h) => h.id === p.policyId,
                              ) ?? {
                                id: text(p.policyId),
                                branchId: p.branchId,
                                name: p.name,
                              },
                              version: p,
                            })
                          }
                        >
                          ویرایش پیش‌نویس
                        </button>
                        <button
                          className="admin-button admin-primary"
                          onClick={() => lifecycle(p, "version.publish")}
                        >
                          فعال‌سازی نسخه
                        </button>
                      </>
                    )}
                    {p.lifecycle === "ACTIVE" && (
                      <button
                        className="admin-button"
                        onClick={() => lifecycle(p, "version.retire")}
                      >
                        بازنشسته کردن نسخه
                      </button>
                    )}
                  </div>
                )}
              </article>
            );
          })}
        </div>
        {!policies.length && (
          <p className="admin-muted">
            نسخه‌ای در محدودهٔ مجاز قابل مشاهده نیست.
          </p>
        )}
      </section>
      <section className="admin-panel">
        <div className="admin-section-head">
          <h2>محدودهٔ اعمال سیاست‌ها</h2>
          {can("policy.manage") && (
            <button className="admin-button" onClick={assignment}>
              اعمال نسخهٔ سیاست
            </button>
          )}
        </div>
        <div className="admin-list">
          {assignments.map((a) => (
            <article key={a.id} className="admin-list-row">
              <div>
                <h3>
                  {text(
                    policies.find((p) => p.id === a.policy_version_id)?.name,
                  ) || "نسخهٔ سیاست"}
                </h3>
                <p>
                  {
                    (
                      {
                        BUSINESS: "کل مجموعه",
                        BRANCH: "این شعبه",
                        SERVICE: "خدمت",
                        STAFF: "عضو تیم",
                        WHOLE_BOOKING: "ترکیب دقیق خدمات",
                      } as Record<string, string>
                    )[text(a.scope_kind)]
                  }{" "}
                  · اولویت {text(a.priority)}
                </p>
              </div>
              <span className="admin-tag">
                {a.revoked_at ? "لغوشده" : "معتبر در بازهٔ ثبت‌شده"}
              </span>
              {!a.revoked_at &&
                can(
                  "policy.manage",
                  a.branch_id === null ? null : text(a.branch_id),
                ) && (
                  <button
                    className="admin-button admin-danger"
                    onClick={() =>
                      open({
                        title: "لغو محدودهٔ اعمال سیاست",
                        fields: [
                          {
                            key: "confirmed",
                            label:
                              "اعمال جدید این محدوده متوقف شود؛ شرایط قبلی حفظ می‌شوند.",
                            type: "checkbox",
                            required: true,
                          },
                        ],
                        save: async (_v, k) => {
                          await command(
                            "assignment.revoke",
                            a.id,
                            {},
                            k,
                            a.branch_id === null ? null : text(a.branch_id),
                          );
                        },
                      })
                    }
                  >
                    لغو اعمال
                  </button>
                )}
            </article>
          ))}
        </div>
      </section>
    </>
  );
}
function PolicyEditor({
  parent,
  versionRow,
  zone,
  branch,
  save,
  cancel,
}: {
  parent: Row;
  versionRow?: Row;
  zone: string;
  branch: string | null;
  save: (terms: unknown, key: string) => Promise<void>;
  cancel: () => void;
}) {
  const old = (versionRow?.terms ?? {}) as Record<string, unknown>,
    [v, setV] = useState<Record<string, string>>(() =>
      Object.fromEntries(
        [
          "depositRequirement",
          "amountKind",
          "fixedRial",
          "minimumRial",
          "maximumRial",
          "refundability",
          "refundBase",
          "cancellationDeadlineMinutes",
          "termsText",
        ]
          .map((k) => [k, text(old[k])])
          .concat([
            ["percentage", percent(old.basisPoints)],
            ["outside", percent(old.outsideRefundBps)],
            ["effectiveFrom", localInput(old.effectiveFrom, zone)],
            ["effectiveTo", localInput(old.effectiveTo, zone)],
          ]),
      ),
    ),
    [windows, setWindows] = useState<{ threshold: string; rate: string }[]>(
      () =>
        (
          (old.refundWindows ?? []) as {
            thresholdMinutes: string;
            refundBps: string;
          }[]
        ).map((w) => ({
          threshold: w.thresholdMinutes,
          rate: percent(w.refundBps),
        })),
    ),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false),
    err = useRef<HTMLDivElement>(null),
    intent = useRef({ signature: "", key: "" });
  const change = (k: string, value: string) =>
    setV((s) => ({ ...s, [k]: value }));
  async function toInstant(value: string, oldValue: unknown) {
    if (oldValue && localInput(oldValue, zone) === value) return oldValue;
    if (!branch) throw Error("برای تبدیل ساعت، ابتدا شعبه را انتخاب کنید.");
    return (
      await api<{ instant: string }>(
        "admin/portal/read/instant" + query({ branchId: branch, local: value }),
      )
    ).instant;
  }
  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError("");
    const signature = JSON.stringify({ v, windows });
    if (intent.current.signature !== signature)
      intent.current = { signature, key: crypto.randomUUID() };
    try {
      const none = v.depositRequirement === "NONE",
        terms = {
          depositRequirement: v.depositRequirement,
          amountKind: none ? null : v.amountKind,
          fixedRial: !none && v.amountKind === "FIXED" ? v.fixedRial : null,
          basisPoints:
            !none && v.amountKind === "PERCENTAGE" ? bps(v.percentage) : null,
          minimumRial: !none && v.minimumRial ? v.minimumRial : null,
          maximumRial: !none && v.maximumRial ? v.maximumRial : null,
          refundability: v.refundability,
          refundBase: v.refundBase,
          outsideRefundBps: bps(v.outside),
          cancellationDeadlineMinutes: v.cancellationDeadlineMinutes,
          termsText: v.termsText,
          termsLocale: text(old.termsLocale) || "fa",
          effectiveFrom: await toInstant(v.effectiveFrom, old.effectiveFrom),
          effectiveTo: v.effectiveTo
            ? await toInstant(v.effectiveTo, old.effectiveTo)
            : null,
          refundWindows: windows
            .map((w) => ({
              thresholdMinutes: w.threshold,
              refundBps: bps(w.rate),
            }))
            .sort(
              (a, b) => Number(a.thresholdMinutes) - Number(b.thresholdMinutes),
            ),
        };
      await save(terms, intent.current.key);
    } catch (e) {
      setError((e as Error).message);
      requestAnimationFrame(() => err.current?.focus());
    } finally {
      setBusy(false);
    }
  }
  const select = (key: string, label: string, choices: [string, string][]) => (
    <div className="admin-field">
      <label htmlFor={"policy-" + key}>{label} *</label>
      <select
        id={"policy-" + key}
        value={v[key]}
        required
        disabled={busy}
        onChange={(e) => change(key, e.target.value)}
      >
        <option value="">انتخاب کنید</option>
        {choices.map(([val, label]) => (
          <option key={val} value={val}>
            {label}
          </option>
        ))}
      </select>
    </div>
  );
  const input = (
    key: string,
    label: string,
    type = "number",
    required = true,
  ) => (
    <div className="admin-field">
      <label htmlFor={"policy-" + key}>
        {label}
        {required ? " *" : ""}
      </label>
      <input
        id={"policy-" + key}
        value={v[key] ?? ""}
        required={required}
        disabled={busy}
        type={type}
        min={type === "number" ? 0 : undefined}
        step={
          key === "percentage" || key === "outside"
            ? "0.01"
            : key.includes("Rial")
              ? "10"
              : undefined
        }
        onChange={(e) => change(key, e.target.value)}
      />
    </div>
  );
  return (
    <section className="admin-editor">
      <div className="admin-section-head">
        <h2>
          {versionRow ? "ویرایش پیش‌نویس شرایط" : "نسخهٔ جدید شرایط"} ·{" "}
          {text(parent.name)}
        </h2>
        <button className="admin-button" disabled={busy} onClick={cancel}>
          بستن فرم شرایط
        </button>
      </div>
      <p className="admin-muted">
        زمان‌ها به وقت {zone} هستند. ذخیره، فقط پیش‌نویس می‌سازد؛ فعال‌سازی و
        اعمال محدوده جداگانه‌اند.
      </p>
      <form onSubmit={submit}>
        {error && (
          <div className="admin-error" role="alert" tabIndex={-1} ref={err}>
            {error}
          </div>
        )}
        <div className="admin-form-grid">
          {select("depositRequirement", "نوع بیعانه", [
            ["NONE", "بدون بیعانه"],
            ["OPTIONAL", "اختیاری"],
            ["REQUIRED", "الزامی"],
          ])}
          {v.depositRequirement && v.depositRequirement !== "NONE" && (
            <>
              {select("amountKind", "محاسبهٔ بیعانه", [
                ["FIXED", "مبلغ ثابت"],
                ["PERCENTAGE", "درصدی"],
              ])}
              {v.amountKind === "FIXED" &&
                input("fixedRial", "مبلغ ثابت (ریال)")}
              {v.amountKind === "PERCENTAGE" &&
                input("percentage", "درصد بیعانه")}
              {input(
                "minimumRial",
                "حداقل بیعانه (ریال، اختیاری)",
                "number",
                false,
              )}
              {input(
                "maximumRial",
                "حداکثر بیعانه (ریال، اختیاری)",
                "number",
                false,
              )}
            </>
          )}
          {select("refundability", "قابلیت بازپرداخت", [
            ["FULL", "کامل"],
            ["NONE", "بدون بازپرداخت"],
            ["PARTIAL", "بخشی"],
            ["CONDITIONAL", "شرطی"],
          ])}
          {select("refundBase", "مبنای محاسبهٔ بازپرداخت", [
            ["DEPOSIT_PAID", "بیعانهٔ پرداخت‌شده"],
            ["ALL_PAID", "تمام مبلغ پرداخت‌شده"],
          ])}
          {input("outside", "درصد بازپرداخت خارج از بازه‌ها")}
          {input(
            "cancellationDeadlineMinutes",
            "مهلت مجاز لغو (دقیقه پیش از شروع)",
          )}
          {input("effectiveFrom", "شروع اعتبار", "datetime-local")}
          {input(
            "effectiveTo",
            "پایان اعتبار (اختیاری)",
            "datetime-local",
            false,
          )}
          <div className="admin-field admin-wide">
            <label htmlFor="policy-termsText">
              متن کامل شرایط قابل پذیرش *
            </label>
            <textarea
              id="policy-termsText"
              value={v.termsText}
              required
              disabled={busy}
              rows={6}
              onChange={(e) => change("termsText", e.target.value)}
            />
          </div>
        </div>
        <fieldset className="admin-policy-windows">
          <legend>بازه‌های بازپرداخت</legend>
          <p className="admin-muted">
            بازه‌ها صرفاً پیکربندی‌اند؛ هیچ وجهی در این محیط پرداخت یا بازپرداخت
            نمی‌شود.
          </p>
          {windows.map((w, i) => (
            <div className="admin-window" key={i}>
              <label>
                دقیقه پیش از شروع
                <input
                  type="number"
                  min={0}
                  required
                  disabled={busy}
                  value={w.threshold}
                  onChange={(e) =>
                    setWindows((a) =>
                      a.map((x, j) =>
                        j === i ? { ...x, threshold: e.target.value } : x,
                      ),
                    )
                  }
                />
              </label>
              <label>
                درصد بازپرداخت
                <input
                  type="number"
                  min={0}
                  max={100}
                  step="0.01"
                  required
                  disabled={busy}
                  value={w.rate}
                  onChange={(e) =>
                    setWindows((a) =>
                      a.map((x, j) =>
                        j === i ? { ...x, rate: e.target.value } : x,
                      ),
                    )
                  }
                />
              </label>
              <button
                type="button"
                className="admin-button"
                disabled={busy}
                onClick={() => setWindows((a) => a.filter((_, j) => j !== i))}
              >
                حذف بازه {i + 1}
              </button>
            </div>
          ))}
          <button
            className="admin-button"
            type="button"
            disabled={busy || windows.length >= 10}
            onClick={() =>
              setWindows((w) => [...w, { threshold: "", rate: "" }])
            }
          >
            افزودن بازهٔ بازپرداخت
          </button>
        </fieldset>
        <div className="admin-form-actions">
          <button
            className="admin-button admin-primary"
            disabled={busy}
            type="submit"
          >
            {busy ? "در حال ثبت…" : "ذخیرهٔ پیش‌نویس شرایط"}
          </button>
        </div>
      </form>
    </section>
  );
}
