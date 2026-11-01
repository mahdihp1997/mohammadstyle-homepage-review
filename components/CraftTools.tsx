import Icon from "@/components/Icon";

/** Decorative salon tools, never a fake actionable control. */
export default function CraftTools() {
  return <div className="craft-tools" aria-hidden="true"><span className="craft-rule"/><Icon name="scissors" size={34}/><svg width="75" height="28" viewBox="0 0 75 28" fill="none" stroke="currentColor" strokeWidth="1.3"><path d="M5 7h64v5H5zM9 12v10m5-10v10m5-10v10m5-10v10m5-10v10m5-10v10m5-10v10m5-10v10m5-10v10m5-10v10m5-10v10m5-10v10"/></svg><span className="craft-rule"/></div>;
}
