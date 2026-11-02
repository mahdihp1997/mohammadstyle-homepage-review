"use client";
import { useEffect, useState, type ReactNode } from "react";

const key = "mohammadstyle-admin-theme";
export default function AdminTheme({ children }: { children: ReactNode }) {
  const [theme, setTheme] = useState<"dark" | "light">("dark");
  useEffect(() => {
    const read = () => { try { setTheme(localStorage.getItem(key)==="light"?"light":"dark"); } catch { /* Storage may be disabled; in-memory switching still works. */ } };
    read(); window.addEventListener("storage", read);
    return () => window.removeEventListener("storage", read);
  }, []);
  return <div className="admin-theme-shell" data-admin-theme={theme}><div className="admin-appearance"><span>نمای پنل مدیریت</span><button type="button" onClick={() => { const value=theme==="dark"?"light":"dark";setTheme(value);try{localStorage.setItem(key,value);}catch{} }} aria-pressed={theme==="light"} aria-label="حالت روشن پنل مدیریت"><span aria-hidden="true">{theme==="dark"?"☀":"☾"}</span>{theme==="dark"?"حالت روشن":"حالت تیره"}</button></div>{children}</div>;
}
