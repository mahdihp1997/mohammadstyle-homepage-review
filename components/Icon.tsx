import type { ReactNode } from "react";

const icons: Record<string, ReactNode> = {
  crown: <><path d="m2 7 4.4 3.4L12 3l5.6 7.4L22 7l-2 11H4L2 7Z"/><path d="M5 21h14"/></>,
  scissors: <><circle cx="6" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><path d="M8.1 8.1 21 21M8.1 15.9 21 3"/></>,
  sparkle: <><path d="m12 2 1.8 7.2L21 11l-7.2 1.8L12 20l-1.8-7.2L3 11l7.2-1.8L12 2Z"/><path d="m19 18 .6 1.4L21 20l-1.4.6L19 22l-.6-1.4L17 20l1.4-.6L19 18Z"/></>,
  leaf: <><path d="M20 4c-8 0-15 2-15 11a6 6 0 0 0 6 6c9 0 11-7 9-17Z"/><path d="M4 21c2-7 6-10 12-13"/></>,
  hand: <><path d="M8 13V5a1.5 1.5 0 0 1 3 0v7M11 12V3a1.5 1.5 0 0 1 3 0v9M14 12V5a1.5 1.5 0 0 1 3 0v8M17 13V8a1.5 1.5 0 0 1 3 0v7c0 5-4 7-8 7H9c-2 0-3-1-4-3L2 14a1.5 1.5 0 0 1 2.4-1.8L8 16"/></>,
  foot: <><path d="M13 6c-1 5-2 7-4 10-1.6 2.2-1 5 2 5h6c3 0 4-3 2-5l-2-2c-2-2-2-6-2-8"/><circle cx="15" cy="3" r="1"/><circle cx="11" cy="4" r="1"/><circle cx="8" cy="6" r="1"/><circle cx="6" cy="9" r="1"/></>,
  calendar: <><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M7 3v4M17 3v4M3 10h18"/></>,
  location: <><path d="M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="3"/></>,
  arrow: <><path d="M20 12H4M11 5l-7 7 7 7"/></>,
  arrowUp: <><path d="M18 16V6H8M18 6 5 19"/></>,
  chevron: <path d="m9 18 6-6-6-6"/>,
  instagram: <><rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><path d="M17.5 6.5h.01"/></>,
  close: <path d="M5 5l14 14M19 5 5 19"/>,
  menu: <path d="M4 7h16M4 12h16M4 17h16"/>,
  check: <path d="m4 13 5 5L20 6"/>,
  clock: <><circle cx="12" cy="12" r="9"/><path d="M12 7v5l4 2"/></>,
  play: <path d="m8 5 11 7-11 7V5Z"/>,
  gift: <><rect x="3" y="10" width="18" height="11" rx="1"/><path d="M2 7h20v3H2zM12 7v14M12 7c-3 0-6-1-6-3 0-3 5-3 6 3ZM12 7c3 0 6-1 6-3 0-3-5-3-6 3Z"/></>,
  quote: <path d="M10 10H4c0-4 2-6 5-7M20 10h-6c0-4 2-6 5-7M4 10v8h6v-8M14 10v8h6v-8"/>
};
export default function Icon({ name, size = 22, className = "" }: { name: string; size?: number; className?: string }) {
  return <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">{icons[name] ?? icons.sparkle}</svg>;
}
