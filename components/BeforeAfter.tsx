"use client";

import { useRef, useState, type CSSProperties, type PointerEvent } from "react";

/** Native keyboard range plus pointer gestures: vertical touch panning belongs to the browser. */
export default function BeforeAfterComparison() {
  const [percent, setPercent] = useState(50);
  const gesture = useRef<{ id: number; x: number; y: number; horizontal: boolean } | null>(null);
  function update(e: PointerEvent<HTMLInputElement>) {
    const bounds = e.currentTarget.getBoundingClientRect();
    setPercent(Math.max(0, Math.min(100, Math.round((e.clientX - bounds.left) / bounds.width * 100))));
  }
  return <div className="compare-frame" style={{ "--split": `${percent}%` } as CSSProperties}>
    <div className="compare-images" dir="ltr">
      <img className="compare-after" src="/images/hair-after.webp" alt="نتیجه بعد از استایل و آراستگی مو" loading="lazy" draggable={false}/>
      <div className="compare-before"><img src="/images/hair-before.webp" alt="نمای پیش از استایل مو" loading="lazy" draggable={false}/></div>
      <div className="compare-divider" aria-hidden="true"><span>↔</span></div>
      <div className="compare-label-region compare-before-label-region"><span className="compare-label compare-label-before" hidden={percent === 0}>BEFORE</span></div>
      <div className="compare-label-region compare-after-label-region"><span className="compare-label compare-label-after" hidden={percent === 100}>AFTER</span></div>
      <input aria-label="مقایسه قبل و بعد؛ درصد نمایش تصویر قبل" aria-valuetext={`${percent}٪ قبل، ${100-percent}٪ بعد`} dir="ltr" className="compare-slider" type="range" min={0} max={100} value={percent}
        onChange={e => { if (!gesture.current) setPercent(Number(e.currentTarget.value)); }}
        onPointerDown={e => {
          if (!e.isPrimary || e.button !== 0) return;
          gesture.current = { id: e.pointerId, x: e.clientX, y: e.clientY, horizontal: e.pointerType === "mouse" };
          if (e.pointerType === "mouse") update(e);
          // Suppress native range dragging, never the browser's vertical touch scroll.
          e.preventDefault();
          e.currentTarget.focus({ preventScroll: true });
          e.currentTarget.setPointerCapture(e.pointerId);
        }}
        onPointerMove={e => {
          const g = gesture.current;
          if (!g || g.id !== e.pointerId) return;
          const dx = Math.abs(e.clientX-g.x), dy = Math.abs(e.clientY-g.y);
          if (!g.horizontal && dx > 6 && dx > dy) g.horizontal = true;
          if (g.horizontal) update(e);
        }}
        onPointerUp={e => {
          const g = gesture.current;
          if (g?.id === e.pointerId && (g.horizontal || Math.hypot(e.clientX-g.x,e.clientY-g.y) < 6)) update(e);
          gesture.current = null;
        }}
        onPointerCancel={() => { gesture.current = null; }}
        onLostPointerCapture={() => { gesture.current = null; }}/>
    </div>
    <div className="compare-bottom"><span>BEFORE / AFTER</span><strong>استایل مو</strong><span>DRAG TO EXPLORE</span></div>
    <div className="compare-actions" role="group" aria-label="نمایش کامل تصاویر قبل و بعد">
      <button type="button" onClick={() => setPercent(100)} aria-pressed={percent===100}>قبل</button>
      <button type="button" onClick={() => setPercent(50)} aria-pressed={percent===50}>مقایسه</button>
      <button type="button" onClick={() => setPercent(0)} aria-pressed={percent===0}>بعد</button>
    </div>
  </div>;
}
