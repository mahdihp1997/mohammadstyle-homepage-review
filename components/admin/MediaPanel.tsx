"use client";
import { useRef, useState, type FormEvent } from "react";
import type { Editor, PortalWrite } from "./types";
import { api, text, statuses, type Row } from "@/lib/mvp/client";
export default function MediaPanel({
  items,
  categories,
  branch,
  can,
  open,
  write,
  notify,
}: {
  items: Row[];
  categories: Row[];
  branch: string | null;
  can: (p: string, b?: string | null) => boolean;
  open: (e: Editor) => void;
  write: PortalWrite;
  notify: (s?: string) => void;
}) {
  const [file, setFile] = useState<File>(),
    [busy, setBusy] = useState(false),
    [progress, setProgress] = useState(""),
    [error, setError] = useState(""),
    [preview, setPreview] = useState<string>();
  const input = useRef<HTMLInputElement>(null),
    err = useRef<HTMLDivElement>(null),
    key = useRef<string>("");
  async function upload(e: FormEvent) {
    e.preventDefault();
    if (!file) return;
    setBusy(true);
    setError("");
    try {
      if (file.size > 32 * 1024 * 1024)
        throw Error("حجم هر فایل یا ZIP حداکثر ۳۲ مگابایت است.");
      setProgress("آماده‌سازی فایل برای انتقال خصوصی…");
      const base64 = await new Promise<string>((resolve, reject) => {
        const r = new FileReader();
        r.onload = () => resolve(String(r.result).split(",")[1]);
        r.onerror = () => reject(Error("خواندن فایل ممکن نشد."));
        r.readAsDataURL(file);
      });
      key.current ||= crypto.randomUUID();
      setProgress("در حال انتقال و تولید نسخه‌های بهینه روی سرور…");
      const result = await api<{ items: Row[] }>("admin/media/upload", {
        method: "POST",
        key: key.current,
        data: { branchId: branch, fileName: file.name, base64 },
      });
      setFile(undefined);
      if (input.current) input.current.value = "";
      key.current = "";
      notify(
        result.items.length.toLocaleString("fa-IR") +
          " رسانه به‌صورت خصوصی ثبت شد؛ هیچ‌کدام منتشر نشده‌اند.",
      );
    } catch (e) {
      setError((e as Error).message);
      requestAnimationFrame(() => err.current?.focus());
    } finally {
      setBusy(false);
      setProgress("");
    }
  }
  function edit(m: Row) {
    open({
      title: "اطلاعات رسانه",
      fields: [
        {
          key: "title",
          label: "عنوان عمومی",
          help: "ویرایش اطلاعات، رسانه را خصوصی می‌کند؛ پس از بررسی، آن را دوباره منتشر کنید.",
        },
        {
          key: "altText",
          label: "متن جایگزین برای دسترسی‌پذیری",
          type: "textarea",
        },
        {
          key: "categoryIds",
          label: "دسته‌ها",
          type: "multi",
          options: categories
            .filter((c) => c.active)
            .map((c) => ({ value: c.id, label: text(c.name) })),
        },
      ],
      initial: {
        title: text(m.title),
        altText: text(m.altText),
        categoryIds: ((m.categories as { id: string }[]) ?? []).map(
          (c) => c.id,
        ),
      },
      save: async (v, k) => {
        await write(
          "media.edit",
          m.id,
          text(m.version),
          { title: v.title, altText: v.altText, categoryIds: v.categoryIds },
          k,
          branch,
        );
      },
    });
  }
  function rights(m: Row, revoke = false) {
    open({
      title: revoke ? "لغو تأیید حق استفاده" : "تأیید حق استفاده برای وب‌سایت",
      fields: [
        {
          key: "evidenceReference",
          label: revoke ? "مرجع و دلیل لغو" : "مرجع مدرک حق استفاده",
          type: "textarea",
          help: "این مرجع خصوصی است. مدرک را واقعاً بررسی کنید؛ ثبت یا تمدید مجوز، نمایش عمومی را متوقف می‌کند و انتشار دوباره لازم است.",
        },
        ...(!revoke
          ? [
              {
                key: "validUntil",
                label: "انقضای مجوز (UTC، اختیاری)",
                type: "datetime-local" as const,
                required: false,
                help: "خالی یعنی تاریخ پایان ثبت نشده است.",
              },
            ]
          : []),
        {
          key: "confirmed",
          label: revoke
            ? "لغو مجوز و توقف نمایش عمومی را تأیید می‌کنم."
            : "حق استفادهٔ وب‌سایت از این رسانه و رضایت تمام افراد قابل‌شناسایی را بر اساس مدارک بررسی و تأیید کرده‌ام.",
          type: "checkbox",
          required: true,
        },
      ],
      submit: revoke ? "ثبت لغو مجوز" : "ثبت تأیید مجوز",
      save: async (v, k) => {
        await write(
          "media.rights",
          m.id,
          text(m.version),
          {
            action: revoke ? "REVOKE" : "GRANT",
            scope: "PUBLIC_WEBSITE",
            confirmed: v.confirmed === true,
            evidenceReference: v.evidenceReference,
            validUntil:
              !revoke && v.validUntil
                ? new Date(String(v.validUntil) + "Z").toISOString()
                : null,
          },
          k,
          branch,
        );
      },
    });
  }
  function changeState(
    m: Row,
    op: "media.publish" | "media.unpublish" | "media.archive",
  ) {
    const label =
      op === "media.publish"
        ? "انتشار در گالری عمومی"
        : op === "media.archive"
          ? "بایگانی خصوصی"
          : "توقف انتشار";
    open({
      title: label,
      fields: [
        {
          key: "confirmed",
          label:
            op === "media.publish"
              ? "عنوان، متن جایگزین، تصویر و مدرک حق استفاده را بررسی و انتشار عمومی را تأیید می‌کنم."
              : op === "media.archive"
                ? "رسانه از نمایش عمومی خارج و با سابقهٔ آن به‌صورت خصوصی نگه‌داری شود."
                : "توقف نمایش عمومی این رسانه را تأیید می‌کنم.",
          type: "checkbox",
          required: true,
        },
      ],
      submit: label,
      save: async (_v, k) => {
        await write(op, m.id, text(m.version), {}, k, branch);
      },
    });
  }
  function category(row?: Row) {
    open({
      title: row ? "ویرایش دسته" : "افزودن دسته",
      fields: [
        { key: "name", label: "نام دسته" },
        {
          key: "slug",
          label: "شناسهٔ انگلیسی دسته",
          help: "حروف کوچک انگلیسی، عدد و خط تیره.",
        },
        { key: "active", label: "دسته فعال است", type: "checkbox" },
      ],
      initial: row
        ? {
            name: text(row.name),
            slug: text(row.slug),
            active: row.active === true,
          }
        : {},
      save: async (v, k) => {
        await write(
          "category.save",
          row?.id ?? null,
          text(row?.version) || "0",
          { name: v.name, slug: v.slug, active: v.active === true },
          k,
          null,
        );
      },
    });
  }
  return (
    <>
      <section className="admin-panel">
        <div className="admin-section-head">
          <h2>بارگذاری خصوصی رسانه</h2>
          <a className="admin-button" href="/portfolio">
            گالری عمومی ↗
          </a>
        </div>
        <p>
          عکس‌ها و ویدئوهای واقعی سالن را اینجا وارد کنید. فایل‌ها ابتدا خصوصی
          می‌مانند؛ تأیید مجوز و انتشار، دو اقدام جدا هستند.
        </p>
        <form onSubmit={upload} className="admin-upload">
          <label htmlFor="media-upload-file">
            انتخاب عکس، ویدئو یا ZIP
            <input
              ref={input}
              id="media-upload-file"
              type="file"
              accept="image/jpeg,image/png,image/webp,video/mp4,video/quicktime,video/webm,.zip"
              required
              disabled={busy}
              onChange={(e) => {
                setFile(e.target.files?.[0]);
                key.current = crypto.randomUUID();
                setError("");
              }}
            />
          </label>
          <small>
            حداکثر ۳۲ مگابایت؛ ویدئو حداکثر ۱۲۰ ثانیه. ZIP: حداکثر ۲۰ رسانه و
            ۱۲۸ مگابایت پس از بازشدن؛ فایل‌های دیگر یا مسیرهای ناامن پذیرفته
            نمی‌شوند. اگر پردازش ZIP بیش از دو دقیقه طول کشید، آن را به بسته‌های
            کوچک‌تر تقسیم کنید.
          </small>
          {file && (
            <p>
              {file.name} ·{" "}
              {(file.size / 1024 / 1024).toLocaleString("fa-IR", {
                maximumFractionDigits: 1,
              })}{" "}
              مگابایت
            </p>
          )}
          <button
            className="admin-button admin-primary"
            disabled={busy || !file}
            type="submit"
          >
            {busy ? "در حال پردازش…" : "بارگذاری خصوصی"}
          </button>
          <div role="status">{progress}</div>
          {busy && <progress aria-label="انتقال و پردازش رسانه" />}
          {error && (
            <div className="admin-error" role="alert" tabIndex={-1} ref={err}>
              {error}
            </div>
          )}
        </form>
        <p className="admin-muted">
          تصویر کوچک و WebP بهینه تولید می‌شود؛ ویدئو با پخش تدریجی MP4 و کاور
          ارائه می‌شود. فایل اصلی به گالری عمومی راه ندارد. ZIP هیچ مجوز انتشاری
          ثبت نمی‌کند.
        </p>
      </section>
      <section className="admin-panel">
        <div className="admin-section-head">
          <h2>دسته‌بندی نمونه‌کارها</h2>
          {can("media.manage", null) && (
            <button className="admin-button" onClick={() => category()}>
              افزودن دسته
            </button>
          )}
        </div>
        <div className="admin-category-list">
          {categories.map((c) => (
            <div key={c.id}>
              <span>
                {text(c.name)} · {c.active ? "فعال" : "غیرفعال"}
              </span>
              {can("media.manage", null) && (
                <button
                  className="admin-text-button"
                  onClick={() => category(c)}
                >
                  ویرایش دسته
                </button>
              )}
            </div>
          ))}
        </div>
        {!categories.length && (
          <p className="admin-muted">هنوز دسته‌ای ثبت نشده است.</p>
        )}
      </section>
      <section className="admin-panel">
        <div className="admin-section-head">
          <h2>کتابخانهٔ رسانه</h2>
          <span className="admin-muted">
            {items.length.toLocaleString("fa-IR")} مورد در این صفحه
          </span>
        </div>
        <div className="admin-media-grid">
          {items.map((m) => {
            const archived = m.state === "ARCHIVED",
              published = m.state === "PUBLISHED",
              ready =
                m.rightsConfirmed === true &&
                !!text(m.title).trim() &&
                !!text(m.altText).trim();
            return (
              <article key={m.id} className="admin-media-card">
                <div className="admin-media-preview">
                  {preview === m.id && m.kind === "VIDEO" ? (
                    <video
                      controls
                      preload="metadata"
                      poster={"/api/mvp/admin/media/view/" + m.id + "/DISPLAY"}
                      src={"/api/mvp/admin/media/view/" + m.id + "/VIDEO"}
                      aria-label={text(m.title) || "ویدئوی خصوصی"}
                    />
                  ) : (
                    <img
                      loading="lazy"
                      src={"/api/mvp/admin/media/view/" + m.id + "/THUMB"}
                      alt={
                        text(m.altText) ||
                        "پیش‌نمایش خصوصی؛ متن جایگزین هنوز تکمیل نشده"
                      }
                      width={480}
                      height={360}
                    />
                  )}
                  <span
                    className={
                      "admin-tag admin-status-" + text(m.state).toLowerCase()
                    }
                  >
                    {statuses[text(m.state)]}
                  </span>
                </div>
                <div className="admin-media-body">
                  <h3>{text(m.title) || "عنوان عمومی ثبت نشده"}</h3>
                  <p className="admin-muted">{text(m.originalName)}</p>
                  <p>
                    {m.rightsConfirmed
                      ? "مجوز وب‌سایت تأیید شده است."
                      : "مجوز معتبر انتشار عمومی ثبت نشده است."}
                  </p>
                  {published && !m.rightsConfirmed && (
                    <p className="admin-error">
                      نمایش عمومی به‌دلیل نبود مجوز معتبر متوقف است.
                    </p>
                  )}
                  <div className="admin-row-actions">
                    {m.kind === "VIDEO" && (
                      <button
                        className="admin-button"
                        onClick={() =>
                          setPreview(preview === m.id ? undefined : m.id)
                        }
                      >
                        {preview === m.id ? "بستن پخش" : "پیش‌نمایش ویدئو"}
                      </button>
                    )}
                    {!archived && (
                      <>
                        <button
                          className="admin-button"
                          onClick={() => edit(m)}
                        >
                          اطلاعات و دسته‌ها
                        </button>
                        {can("media.rights.manage", branch) && (
                          <>
                            <button
                              className="admin-button"
                              onClick={() => rights(m)}
                            >
                              ثبت یا تمدید حق استفاده
                            </button>
                            {m.rightsConfirmed === true && (
                              <button
                                className="admin-text-button admin-danger"
                                onClick={() => rights(m, true)}
                              >
                                لغو تأیید حق استفاده
                              </button>
                            )}
                          </>
                        )}
                        {published ? (
                          <button
                            className="admin-button"
                            onClick={() => changeState(m, "media.unpublish")}
                          >
                            توقف انتشار
                          </button>
                        ) : (
                          can("media.publish", branch) && (
                            <button
                              className="admin-button admin-primary"
                              disabled={!ready}
                              onClick={() => changeState(m, "media.publish")}
                            >
                              انتشار عمومی
                            </button>
                          )
                        )}
                        <button
                          className="admin-text-button admin-danger"
                          onClick={() => changeState(m, "media.archive")}
                        >
                          بایگانی
                        </button>
                      </>
                    )}
                  </div>
                  {!archived && !ready && (
                    <small className="admin-muted">
                      برای انتشار، عنوان، متن جایگزین و مجوز معتبر لازم است.
                    </small>
                  )}
                  <details>
                    <summary>سابقهٔ حق استفاده</summary>
                    {(
                      (m.rightsEvents as {
                        action: string;
                        evidenceReference: string;
                        at: string;
                      }[]) ?? []
                    ).length ? (
                      (
                        m.rightsEvents as {
                          action: string;
                          evidenceReference: string;
                          at: string;
                        }[]
                      ).map((r, i) => (
                        <p key={i}>
                          {r.action === "GRANT" ? "تأیید" : "لغو"} ·{" "}
                          {r.evidenceReference}
                        </p>
                      ))
                    ) : (
                      <p>سابقه‌ای ثبت نشده است.</p>
                    )}
                  </details>
                </div>
              </article>
            );
          })}
        </div>
        {!items.length && (
          <div className="admin-empty">
            رسانه‌ای در این محدوده وجود ندارد. بارگذاری دستی یا ZIP را شروع
            کنید.
          </div>
        )}
      </section>
    </>
  );
}
