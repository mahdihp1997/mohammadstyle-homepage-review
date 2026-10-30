"use client";
import { useEffect, useRef, useState } from "react";
type Asset = {
  id: string;
  kind: "IMAGE" | "VIDEO";
  title: string;
  altText: string;
  categories: { id: string; name: string; slug: string }[];
  variants: { name: string; width: number; height: number }[];
};
type Gallery = {
  items: Asset[];
  categories: { id: string; name: string; slug: string }[];
  limit: number;
  offset: number;
};
export default function PortfolioGallery({ enabled }: { enabled: boolean }) {
  const [items, setItems] = useState<Asset[]>([]),
    [categories, setCategories] = useState<Gallery["categories"]>([]),
    [category, setCategory] = useState(""),
    [kind, setKind] = useState("ALL"),
    [offset, setOffset] = useState(0),
    [more, setMore] = useState(false),
    [loading, setLoading] = useState(enabled),
    [error, setError] = useState(""),
    [reload, setReload] = useState(0),
    [selected, setSelected] = useState<Asset>();
  const opener = useRef<HTMLElement | null>(null),
    dialog = useRef<HTMLDialogElement>(null),
    message = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!enabled) return;
    const c = new AbortController();
    setLoading(true);
    setError("");
    if (offset === 0) setItems([]);
    const q = new URLSearchParams({ offset: String(offset) });
    if (category) q.set("category", category);
    fetch("/api/portfolio?" + q, { cache: "no-store", signal: c.signal })
      .then(async (r) => {
        if (!r.ok) throw Error("دریافت گالری ممکن نشد. دوباره تلاش کنید.");
        return (await r.json()) as Gallery;
      })
      .then((d) => {
        if (!c.signal.aborted) {
          setItems((old) =>
            offset === 0
              ? d.items
              : [
                  ...old,
                  ...d.items.filter((x) => !old.some((o) => o.id === x.id)),
                ],
          );
          setCategories(d.categories);
          setMore(d.items.length === d.limit);
        }
      })
      .catch((e) => {
        if (!c.signal.aborted) {
          setError((e as Error).message);
          requestAnimationFrame(() => message.current?.focus());
        }
      })
      .finally(() => {
        if (!c.signal.aborted) setLoading(false);
      });
    return () => c.abort();
  }, [category, offset, reload, enabled]);
  useEffect(() => {
    if (!selected || !dialog.current) return;
    const d = dialog.current;
    d.showModal();
    return () => {
      d.close();
      requestAnimationFrame(() => {
        if (opener.current?.isConnected) opener.current.focus();
      });
    };
  }, [selected]);
  const visible = items.filter((x) => kind === "ALL" || x.kind === kind),
    assetUrl = (m: Asset, v: string) => "/api/portfolio/" + m.id + "/" + v;
  return (
    <div className="portfolio-page">
      <header className="portfolio-header">
        <a href="/" className="portfolio-brand">
          محمد استایل<small>MOHAMMAD STYLE</small>
        </a>
        <a className="btn btn-ghost" href="/">
          بازگشت به خانه
        </a>
      </header>
      <main className="portfolio-main">
        <section className="portfolio-intro">
          <span className="portfolio-eyebrow">THE GALLERY</span>
          <h1>نمونه‌کارهای تأییدشده</h1>
          <p>
            عکس و ویدئو، با جزئیات و زاویهٔ کامل.
            <br />
            این گالری فقط رسانهٔ دارای مجوز معتبر وب‌سایت را نمایش می‌دهد.
          </p>
          {enabled && (
            <p className="portfolio-environment">
              محیط توسعهٔ جداگانه · دادهٔ آزمایشی، نمونه‌کار واقعی سالن محسوب
              نمی‌شود.
            </p>
          )}
        </section>
        <section aria-label="گالری نمونه‌کار">
          <div className="portfolio-filters">
            <div role="group" aria-label="دسته‌بندی">
              <button
                aria-pressed={!category}
                onClick={() => {
                  setCategory("");
                  setOffset(0);
                }}
              >
                همهٔ دسته‌ها
              </button>
              {categories.map((c) => (
                <button
                  key={c.id}
                  aria-pressed={category === c.slug}
                  onClick={() => {
                    setCategory(c.slug);
                    setOffset(0);
                  }}
                >
                  {c.name}
                </button>
              ))}
            </div>
            <div role="group" aria-label="نوع رسانه">
              {[
                ["ALL", "همهٔ رسانه‌ها"],
                ["IMAGE", "عکس"],
                ["VIDEO", "ویدئو"],
              ].map(([id, label]) => (
                <button
                  key={id}
                  aria-pressed={kind === id}
                  onClick={() => setKind(id)}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>
          <div role="status" className="portfolio-feedback">
            {loading ? "در حال دریافت رسانه‌های مجاز…" : ""}
          </div>
          {error && (
            <div
              ref={message}
              role="alert"
              tabIndex={-1}
              className="portfolio-error"
            >
              {error}
              <button onClick={() => setReload((x) => x + 1)}>
                تلاش دوباره
              </button>
            </div>
          )}
          <div className="portfolio-grid">
            {visible.map((m) => {
              const v = m.variants.find((x) => x.name === "DISPLAY")!;
              return (
                <article key={m.id} className="portfolio-item">
                  <figure>
                    {m.kind === "VIDEO" ? (
                      <video
                        controls
                        playsInline
                        preload="none"
                        poster={assetUrl(m, "THUMB")}
                        src={assetUrl(m, "VIDEO")}
                        aria-label={m.altText}
                      />
                    ) : (
                      <button
                        className="portfolio-image-button"
                        onClick={(e) => {
                          opener.current = e.currentTarget;
                          setSelected(m);
                        }}
                        aria-label={"نمایش کامل " + m.title}
                      >
                        <img
                          loading="lazy"
                          src={assetUrl(m, "DISPLAY")}
                          alt={m.altText}
                          width={v?.width ?? 1000}
                          height={v?.height ?? 1000}
                        />
                        <span>نمایش کامل ↗</span>
                      </button>
                    )}
                  </figure>
                  <div className="portfolio-caption">
                    <span>{m.kind === "VIDEO" ? "ویدئو" : "عکس"}</span>
                    <h2>{m.title}</h2>
                    <p>{m.categories.map((c) => c.name).join(" / ")}</p>
                  </div>
                </article>
              );
            })}
          </div>
          {!loading && !visible.length && (
            <div className="portfolio-empty">
              <h2>
                {enabled
                  ? "هنوز رسانهٔ مجازی در این انتخاب منتشر نشده است."
                  : "گالری هنوز منتشر نشده است."}
              </h2>
              <p>تصویر جایگزین یا رسانهٔ بدون مجوز نمایش داده نمی‌شود.</p>
            </div>
          )}
          {more && (
            <button
              className="btn btn-gold portfolio-more"
              disabled={loading}
              onClick={() => setOffset((x) => x + 24)}
            >
              نمایش بیشتر
            </button>
          )}
        </section>
      </main>
      <footer className="portfolio-footer">
        <span>محمد استایل · سالن ممتاز پونک</span>
        <a href={enabled ? "/booking?mode=server" : "/booking"}>
          انتخاب زمان و خدمت ↗
        </a>
      </footer>
      {selected && (
        <dialog
          ref={dialog}
          className="portfolio-dialog"
          aria-labelledby="portfolio-detail-title"
          onCancel={(e) => {
            e.preventDefault();
            setSelected(undefined);
          }}
          onClick={(e) => {
            if (e.target === e.currentTarget) setSelected(undefined);
          }}
        >
          <div>
            <div className="portfolio-dialog-head">
              <h2 id="portfolio-detail-title">{selected.title}</h2>
              <button
                autoFocus
                className="btn btn-ghost"
                onClick={() => setSelected(undefined)}
              >
                بستن تصویر
              </button>
            </div>
            <img src={assetUrl(selected, "DISPLAY")} alt={selected.altText} />
            <p>{selected.categories.map((c) => c.name).join(" / ")}</p>
          </div>
        </dialog>
      )}
    </div>
  );
}
