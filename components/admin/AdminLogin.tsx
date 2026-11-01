"use client";
import { useEffect, useRef, useState, type FormEvent } from "react";
import BrandMark from "@/components/BrandMark";
import Icon from "@/components/Icon";

export default function AdminLogin({ enabled }: { enabled: boolean }) {
  const [username, setUsername] = useState(""), [password, setPassword] = useState("");
  const [visible, setVisible] = useState(false), [busy, setBusy] = useState(false), [error, setError] = useState("");
  const [interactive, setInteractive] = useState(false);
  useEffect(() => { setInteractive(true); }, []);
  const alertRef = useRef<HTMLDivElement>(null);
  useEffect(() => { if (error) alertRef.current?.focus(); }, [error]);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); if (busy) return;
    setBusy(true); setError("");
    try {
      const nonce = await fetch("/api/local-review/login", { credentials: "same-origin", cache: "no-store" });
      if (!nonce.ok) throw Error("ورود محلی در دسترس نیست. فعال بودن سرور آزمایشی را بررسی کنید.");
      const challenge = await nonce.json();
      const response = await fetch("/api/local-review/login", { method: "POST", credentials: "same-origin",
        headers: { "content-type": "application/json", "x-login-csrf": challenge.csrfToken },
        body: JSON.stringify({ username, password }) });
      if (response.status === 401) throw Error("نام کاربری یا رمز عبور درست نیست.");
      if (response.status === 429) throw Error("تعداد تلاش‌ها زیاد است. یک دقیقه صبر کنید و دوباره تلاش کنید.");
      if (!response.ok) throw Error("ورود انجام نشد. اتصال به سرور آزمایشی را بررسی و دوباره تلاش کنید.");
      setPassword(""); window.location.assign("/admin");
    } catch (e) { setError(e instanceof Error ? e.message : "ورود انجام نشد. دوباره تلاش کنید."); }
    finally { setBusy(false); }
  }
  return <div className="admin-login-page">
    <header className="admin-login-header"><a className="brand" href="/" aria-label="محمد استایل؛ صفحه اصلی">
      <BrandMark asImage /><span className="brand-name">محمد استایل<span>MOHAMMAD STYLE</span></span>
    </a><a className="admin-login-home" href="/">بازگشت به خانه <Icon name="chevron" size={16} /></a></header>
    <main className="admin-login-main"><section className="admin-login-card" aria-labelledby="login-title">
      <span className="section-eyebrow">MOHAMMAD STYLE / ADMIN</span>
      <h1 id="login-title">ورود به مدیریت</h1>
      <p className="admin-login-intro">با حساب محلی خود وارد فضای مدیریت سالن شوید.</p>
      <div className="admin-login-context"><span className="gold-dot" />محیط توسعهٔ جداگانه</div>
      {enabled ? <form onSubmit={submit} method="post" action="/api/local-review/login" aria-busy={busy || !interactive}>
        <noscript><p className="admin-login-note">برای ورود امن، JavaScript را فعال کنید.</p></noscript>
        <fieldset className="admin-login-fields" disabled={!interactive || busy}><legend className="sr-only">حساب محلی مدیریت</legend>
        {error && <div className="admin-login-error" role="alert" tabIndex={-1} ref={alertRef}>{error}</div>}
        <label htmlFor="login-username">نام کاربری</label>
        <input id="login-username" name="username" value={username} onChange={e => setUsername(e.target.value)}
          autoComplete="username" autoCapitalize="none" spellCheck={false} dir="ltr" required maxLength={64} disabled={busy} />
        <label htmlFor="login-password">رمز عبور</label>
        <div className="admin-login-password"><input id="login-password" name="password" type={visible ? "text" : "password"}
          value={password} onChange={e => setPassword(e.target.value)} autoComplete="current-password" dir="ltr"
          required maxLength={128} disabled={busy} />
          <button type="button" className="admin-login-toggle" onClick={() => setVisible(x => !x)}
            aria-pressed={visible} aria-controls="login-password" disabled={busy}>{visible ? "پنهان کردن" : "نمایش رمز"}</button></div>
        <button type="submit" className="btn btn-gold admin-login-submit" disabled={busy}>{busy ? "در حال ورود…" : "ورود به پنل"}</button>
        <p className="admin-login-note">نشست این مرورگر مستقل است. پس از ۱۵ دقیقه عدم فعالیت یا یک ساعت، دوباره وارد شوید.</p>
        </fieldset>
      </form> : <p className="admin-login-error" role="status">ورود محلی هنوز پیکربندی نشده است. این صفحه در محیط تولید ورود فعال ندارد.</p>}
    </section><p className="admin-login-footnote">محمد استایل · سالن ممتاز پونک</p></main>
  </div>;
}
