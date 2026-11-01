"use client";
import { useEffect, useRef, useState } from "react";
import BrandMark from "@/components/BrandMark";

/** Owner-supplied films remain behind the existing private review asset gate. */
export default function CinematicMedia({ publicAssets, videoSrc, posterSrc, chapter = false, controls = true }: {
  publicAssets: boolean; videoSrc?: string; posterSrc?: string; chapter?: boolean; controls?: boolean;
}) {
  // Public code review omits owner films; existing abstract photo placeholders remain.
  videoSrc = undefined;
  const [selected, setSelected] = useState(videoSrc ? -1 : 0);
  const [playing, setPlaying] = useState(false);
  const video = useRef<HTMLVideoElement>(null);
  const userPaused = useRef(false), userRequested = useRef(false);
  useEffect(() => {
    const node = video.current;
    if (!node || publicAssets || !videoSrc || selected !== -1) return;
    const motion = matchMedia("(prefers-reduced-motion: reduce)");
    const connection = (navigator as Navigator & { connection?: EventTarget & { saveData?: boolean } }).connection;
    let visible = false, disposed = false;
    const sync = () => {
      const allowed = userRequested.current || (!motion.matches && !connection?.saveData);
      if (visible && !document.hidden && allowed && !userPaused.current) {
        if (!node.getAttribute("src")) { node.src = videoSrc; node.load(); }
        node.play().catch(() => { if (!disposed) setPlaying(false); });
      } else node.pause();
    };
    const observer = new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; sync(); }, { threshold: .2 });
    observer.observe(node);
    motion.addEventListener("change", sync);
    connection?.addEventListener("change", sync);
    document.addEventListener("visibilitychange", sync);
    return () => {
      disposed = true; observer.disconnect(); motion.removeEventListener("change", sync);
      connection?.removeEventListener("change", sync); document.removeEventListener("visibilitychange", sync); node.pause();
    };
  }, [publicAssets, videoSrc, selected]);
  if (publicAssets) return <div className="public-brand-art" aria-hidden="true"><BrandMark/><span>MOHAMMAD STYLE</span></div>;
  const photos = [
    { src: "/images/hero-groom.webp", alt: "آرایشگر محمد استایل در حال آماده‌سازی موی مشتری با لباس رسمی", label: "هنر اصلاح" },
    { src: "/images/salon-team.webp", alt: "آرایشگر و مشتری با استایل مو و لباس رسمی در آینهٔ سالن", label: "استایل دامادی" },
    { src: "/images/salon-light.webp", alt: "صندلی‌ها، آینه‌ها و فضای روشن سالن", label: "فضای سالن" },
  ];
  return <>
    <img className="hero-main-image" src={selected < 0 ? (posterSrc || photos[0].src) : photos[selected].src} alt={selected < 0 ? "نمای سالن محمد استایل" : photos[selected].alt} fetchPriority={chapter ? "auto" : "high"} loading={chapter ? "lazy" : "eager"}/>
    {videoSrc && selected === -1 && <>
      <video ref={video} className="hero-background-video" poster={posterSrc || photos[0].src} muted loop playsInline preload="none" aria-hidden="true" onPlay={() => setPlaying(true)} onPause={() => setPlaying(false)} onError={() => setPlaying(false)}/>
      {controls && <button className="hero-video-toggle" type="button" aria-label={playing ? "توقف ویدئوی پس‌زمینه" : "پخش ویدئوی پس‌زمینه"} onClick={() => {
        const node = video.current; if (!node) return;
        if (node.paused) {
          userPaused.current = false; userRequested.current = true;
          if (!node.getAttribute("src") || node.error) { node.src = videoSrc; node.load(); }
          node.play().catch(() => setPlaying(false));
        } else { userPaused.current = true; node.pause(); }
      }}>{playing ? "Ⅱ توقف ویدئو" : "▷ پخش ویدئو"}</button>}
    </>}
    {!chapter && <div className="hero-photo-picker" role="group" aria-label="قاب‌های محمد استایل">
      {videoSrc && <button type="button" aria-pressed={selected === -1} aria-label="فیلم سالن" onClick={() => setSelected(-1)}><img src={posterSrc || photos[0].src} alt="" loading="lazy"/><span>▷ فیلم سالن</span></button>}
      {photos.map((photo, i) => <button key={photo.src} type="button" aria-pressed={selected === i} aria-label={photo.label} onClick={() => setSelected(i)}><img src={photo.src} alt="" loading="lazy"/><span>{photo.label}</span></button>)}
    </div>}
  </>;
}
