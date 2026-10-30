"use client";
import { useEffect, useRef, useState } from "react";
import { AdminForm, type Field, type Option, type Values } from "./AdminForm";
import type { Actor, Editor, Workspace } from "./types";
import MediaPanel from "./MediaPanel";
import PolicyPanel from "./PolicyPanel";
import {
  api,
  query,
  name,
  text,
  money,
  dateTime,
  today,
  addDays,
  minute,
  toMinute,
  pageItems,
  statuses,
  type Row,
  type Page,
} from "@/lib/mvp/client";
const tabs = [
  ["overview", "نمای کلی", "business.read"],
  ["branches", "شعبه‌ها", "branch.read"],
  ["services", "خدمات", "catalog.read"],
  ["prices", "تعرفه و منابع", "offering.read"],
  ["policies", "سیاست بیعانه", "policy.read"],
  ["staff", "تیم سالن", "staff.read"],
  ["schedule", "تقویم کاری", "schedule.read"],
  ["reservations", "رزروها و سابقه", "booking.read"],
  ["media", "رسانه و نمونه‌کار", "media.manage"],
] as const;
const weekdays = [
  ["6", "شنبه"],
  ["7", "یکشنبه"],
  ["1", "دوشنبه"],
  ["2", "سه‌شنبه"],
  ["3", "چهارشنبه"],
  ["4", "پنج‌شنبه"],
  ["5", "جمعه"],
].map(([value, label]) => ({ value, label }));
const physical = [
  { value: "CHAIR", label: "صندلی" },
  { value: "ROOM", label: "اتاق" },
  { value: "DEVICE", label: "دستگاه" },
];
const options = (rows: Row[], get: (r: Row) => string = name): Option[] =>
  rows.map((r) => ({ value: r.id, label: get(r) || "بدون عنوان" }));
const initial = (r: Row, keys: string[]): Values =>
  Object.fromEntries(
    keys.map((k) => [
      k,
      typeof r[k] === "boolean" ? (r[k] as boolean) : text(r[k]),
    ]),
  );
const field = (
  key: string,
  label: string,
  type: Field["type"] = "text",
  other: Partial<Field> = {},
): Field => ({ key, label, type, ...other });
function Icon({ kind = "overview" }: { kind?: string }) {
  const paths: Record<string, string> = {
    overview: "M3 3h7v7H3z M14 3h7v7h-7z M3 14h7v7H3z M14 14h7v7h-7z",
    branches: "M3 21h18 M5 21V8l7-5 7 5v13 M9 21v-7h6v7",
    services: "M4 7h16 M7 3v18 M17 3v18 M4 17h16",
    prices: "M3 5h18v14H3z M8 9h8 M8 13h5",
    policies: "M12 3 3 7v6c0 4 5 7 9 9 4-2 9-5 9-9V7z M8 12l3 3 5-6",
    staff:
      "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2 M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8 M18 6a4 4 0 0 1 0 8 M22 21v-2a4 4 0 0 0-3-4",
    schedule: "M3 6h18v15H3z M7 3v6 M17 3v6 M3 11h18 M8 15h3 M14 15h3",
    reservations: "M7 3h10v18H7z M10 7h4 M10 11h4 M10 15h4",
    media: "M3 3h18v18H3z M3 17l6-6 4 4 3-3 5 5 M15 7h2",
  };
  return (
    <svg
      width="21"
      height="21"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.4"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d={paths[kind] ?? paths.overview} />
    </svg>
  );
}
export default function AdminDashboard({
  initialView,
}: {
  initialView?: string;
}) {
  const [view, setView] = useState(
      tabs.some((t) => t[0] === initialView) ? initialView! : "overview",
    ),
    [branch, setBranch] = useState<string | null>(null),
    [scope, setScope] = useState(false),
    [from, setFrom] = useState(today()),
    [history, setHistory] = useState(false),
    [offset, setOffset] = useState(0),
    [revision, setRevision] = useState(0),
    [workspace, setWorkspace] = useState<Workspace>(),
    [loading, setLoading] = useState(true),
    [error, setError] = useState(""),
    [toast, setToast] = useState(""),
    [editor, setEditor] = useState<Editor>(),
    [mobileMenu, setMobileMenu] = useState(false),
    [detail, setDetail] = useState<Row>();
  const sidebarRef = useRef<HTMLElement>(null),
    errorRef = useRef<HTMLDivElement>(null),
    menuRef = useRef<HTMLButtonElement>(null),
    actor = workspace?.actor;
  const can = (p: string, b: string | null = branch) =>
    !!actor?.assignments.some(
      (x) =>
        x.permission === p &&
        (x.branchId === null || (b !== null && x.branchId === b)),
    );
  const refresh = () => setRevision((x) => x + 1),
    notify = (message = "تغییرات با تأیید سرور ذخیره شد.") => {
      setToast(message);
      refresh();
    };
  useEffect(() => {
    if (!error) return;
    const frame = requestAnimationFrame(() => errorRef.current?.focus());
    return () => cancelAnimationFrame(frame);
  }, [error]);
  useEffect(() => {
    const c = new AbortController();
    setLoading(true);
    setError("");
    api<Workspace>(
      "admin/portal/workspace" +
        query({
          view,
          branchId: scope ? null : branch,
          from,
          to: addDays(from, 7),
          history,
          offset,
        }),
      { signal: c.signal },
    )
      .then((r) => {
        if (!c.signal.aborted) {
          setWorkspace(r);
          if (!scope && branch === null && r.selectedBranchId)
            setBranch(r.selectedBranchId);
        }
      })
      .catch((e) => {
        if (!c.signal.aborted) {
          setError((e as Error).message);
          requestAnimationFrame(() => errorRef.current?.focus());
        }
      })
      .finally(() => {
        if (!c.signal.aborted) setLoading(false);
      });
    return () => c.abort();
  }, [view, branch, scope, from, history, offset, revision]);
  function closeMenu() {
    setMobileMenu(false);
    requestAnimationFrame(() => menuRef.current?.focus());
  }
  useEffect(() => {
    if (!mobileMenu) return;
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    requestAnimationFrame(() =>
      sidebarRef.current
        ?.querySelector<HTMLButtonElement>(".admin-drawer-close")
        ?.focus(),
    );
    function key(e: KeyboardEvent) {
      if (e.key === "Escape") {
        e.preventDefault();
        closeMenu();
      }
      if (e.key === "Tab") {
        const items = Array.from(
          sidebarRef.current?.querySelectorAll<HTMLElement>(
            "a[href],button:not([disabled])",
          ) ?? [],
        ).filter((x) => x.getClientRects().length);
        const first = items[0],
          last = items.at(-1);
        if (e.shiftKey && document.activeElement === first) {
          e.preventDefault();
          last?.focus();
        } else if (!e.shiftKey && document.activeElement === last) {
          e.preventDefault();
          first?.focus();
        }
      }
    }
    function resize() {
      if (innerWidth > 900) closeMenu();
    }
    window.addEventListener("keydown", key);
    window.addEventListener("resize", resize);
    return () => {
      document.body.style.overflow = previous;
      window.removeEventListener("keydown", key);
      window.removeEventListener("resize", resize);
    };
  }, [mobileMenu]);
  useEffect(() => {
    const fn = () => {
      const v = new URLSearchParams(location.search).get("view");
      setView(tabs.some((t) => t[0] === v) ? v! : "overview");
      setEditor(undefined);
    };
    window.addEventListener("popstate", fn);
    return () => window.removeEventListener("popstate", fn);
  }, []);
  const branches = pageItems(workspace?.branches),
    services = pageItems(workspace?.services),
    data = workspace?.data ?? {},
    rows = (key: string) => pageItems(data[key]),
    currentBranch = branches.find((b) => b.id === branch),
    zone = text(currentBranch?.timeZone) || "Asia/Tehran",
    staff = rows("staff"),
    offerings = rows("offerings"),
    staffName = (id: unknown) =>
      name(
        staff.find((x) => x.id === id) ?? { id: "", displayName: "عضو تیم" },
      ),
    serviceName = (id: unknown) =>
      name(
        services.find((x) => x.id === id) ?? { id: "", displayName: "خدمت" },
      );
  const open = (config: Editor) => {
    setDetail(undefined);
    setToast("");
    setEditor(config);
  };
  function navigate(id: string) {
    setView(id);
    setEditor(undefined);
    setDetail(undefined);
    setHistory(false);
    setOffset(0);
    setScope(false);
    setMobileMenu(false);
    window.history.pushState({}, "", "/admin?view=" + id);
    requestAnimationFrame(() =>
      document.getElementById("admin-content")?.focus(),
    );
  }
  const write = async (
    op: string,
    id: string | null,
    version: string,
    d: unknown,
    key: string,
    b: string | null = scope ? null : branch,
  ) => {
    const r = await api<Row>("admin/portal/commands/" + op, {
      method: "POST",
      data: { branchId: b, entityId: id, version, data: d },
      key,
    });
    notify();
    return r;
  };
  const wf = async (
    op: string,
    path: string,
    d: unknown,
    key: string,
    method: "POST" | "PUT" = "POST",
  ) => {
    await api(path, {
      method,
      data: d,
      key,
      version: text(data.context?.version) || "1",
    });
    notify();
  };
  function branchForm(row?: Row) {
    open({
      title: row ? "ویرایش شعبه" : "افزودن شعبه",
      fields: [
        field("code", "کد شعبه"),
        field("displayName", "نام شعبه"),
        field("address", "نشانی", "textarea", { required: false }),
        field("timeZone", "منطقهٔ زمانی IANA", "text", {
          help: "مثلاً Asia/Tehran؛ تغییر شعبهٔ دارای برنامه نیاز به بازبینی دارد.",
        }),
        field("active", "شعبه فعال است", "checkbox"),
      ],
      initial: row
        ? initial(row, ["code", "displayName", "address", "timeZone", "active"])
        : {},
      save: async (v, key) => {
        await write(
          "branch.save",
          row?.id ?? null,
          text(row?.version) || "0",
          {
            code: v.code,
            displayName: v.displayName,
            address: v.address || null,
            timeZone: v.timeZone,
            active: v.active === true,
          },
          key,
          row?.id ?? null,
        );
      },
    });
  }
  function serviceForm(row?: Row) {
    open({
      title: row ? "ویرایش خدمت" : "افزودن خدمت",
      fields: [
        field("code", "کد خدمت"),
        field("displayName", "نام خدمت"),
        field("description", "توضیح", "textarea", { required: false }),
        field("active", "خدمت فعال است", "checkbox"),
      ],
      initial: row
        ? initial(row, ["code", "displayName", "description", "active"])
        : {},
      save: async (v, key) => {
        await write(
          "service.save",
          row?.id ?? null,
          text(row?.version) || "0",
          {
            code: v.code,
            displayName: v.displayName,
            description: v.description || null,
            active: v.active === true,
          },
          key,
          null,
        );
      },
    });
  }
  function priceForm(o: Row) {
    const price = o.price as { amountRial?: string } | null;
    open({
      title: "تعرفه و زمان · " + serviceName(o.serviceId),
      fields: [
        field("priceRial", "قیمت به ریال", "number", { min: 0, step: 10 }),
        field("durationMinutes", "مدت خدمت (دقیقه)", "number", {
          min: 1,
          max: 1440,
        }),
        field(
          "bufferBeforeMinutes",
          "آماده‌سازی پیش از خدمت (دقیقه)",
          "number",
          { min: 0, max: 1440 },
        ),
        field("bufferAfterMinutes", "آماده‌سازی پس از خدمت (دقیقه)", "number", {
          min: 0,
          max: 1440,
        }),
      ],
      initial: {
        priceRial: text(price?.amountRial),
        ...initial(o, [
          "durationMinutes",
          "bufferBeforeMinutes",
          "bufferAfterMinutes",
        ]),
      },
      save: async (v, key) => {
        await write(
          "offering.configure",
          o.id,
          text(o.version),
          {
            priceRial: text(v.priceRial),
            durationMinutes: Number(v.durationMinutes),
            bufferBeforeMinutes: Number(v.bufferBeforeMinutes),
            bufferAfterMinutes: Number(v.bufferAfterMinutes),
          },
          key,
        );
      },
    });
  }
  function staffForm(s?: Row) {
    open({
      title: s ? "ویرایش عضو تیم" : "افزودن عضو تیم",
      fields: [
        field("displayName", "نام نمایشی"),
        ...(s ? [field("active", "عضو تیم فعال است", "checkbox")] : []),
      ],
      initial: s ? { displayName: name(s), active: s.active === true } : {},
      save: async (v, key) => {
        await wf(
          s ? "staff.update" : "staff.create",
          s ? "admin/staff/" + s.id : "admin/staff",
          s
            ? { displayName: v.displayName, active: v.active === true }
            : { displayName: v.displayName },
          key,
          s ? "PUT" : "POST",
        );
      },
    });
  }
  const select = (
    key: string,
    label: string,
    items: Row[],
    get?: (r: Row) => string,
    required = true,
  ) => field(key, label, "select", { options: options(items, get), required });
  function staffTool(kind: string) {
    const memberRows = rows("assignments"),
      qRows = rows("qualifications"),
      memberName = (r: Row) =>
        staffName(r.staff_id) +
        " · " +
        text(r.valid_from) +
        " تا " +
        (text(r.valid_to) || "بدون پایان"),
      qName = (r: Row) =>
        staffName(r.staff_id) + " · " + serviceName(r.service_id);
    const configs: Record<string, Editor> = {
      assignment: {
        title: "عضویت در شعبه",
        fields: [
          select("staffId", "عضو تیم", staff),
          field("validFrom", "شروع عضویت (میلادی)", "date"),
          field("validTo", "پایان اختیاری (میلادی)", "date", {
            required: false,
          }),
        ],
        save: async (v, k) => {
          await wf(
            "assignment.create",
            "admin/branches/" + branch + "/branch-assignments",
            {
              staffId: v.staffId,
              validFrom: v.validFrom,
              validTo: v.validTo || null,
            },
            k,
          );
        },
      },
      close: {
        title: "پایان عضویت؛ حفظ سابقه",
        fields: [
          select(
            "assignment",
            "عضویت",
            memberRows.filter((r) => !r.valid_to),
            memberName,
          ),
          field("validTo", "پایان عضویت (میلادی)", "date"),
          field("reason", "دلیل", "textarea"),
        ],
        save: async (v, k) => {
          await wf(
            "assignment.close",
            "admin/branches/" +
              branch +
              "/branch-assignments/" +
              v.assignment +
              "/end",
            { validTo: v.validTo, reason: v.reason },
            k,
          );
        },
      },
      qualification: {
        title: "تأیید صلاحیت خدمت",
        fields: [
          select("staffId", "عضو تیم", staff),
          select("serviceId", "خدمت", services),
          field("evidenceReference", "مرجع بررسی صلاحیت", "textarea", {
            help: "نام عضو یا مدرک را حدس نزنید؛ مرجع بررسی واقعی را ثبت کنید.",
          }),
          field("active", "صلاحیت تأیید و فعال است", "checkbox"),
        ],
        save: async (v, k) => {
          await wf(
            "qualification.set",
            "admin/staff/qualifications",
            {
              staffId: v.staffId,
              serviceId: v.serviceId,
              evidenceReference: v.evidenceReference,
              active: v.active === true,
            },
            k,
            "POST",
          );
        },
      },
      eligibility: {
        title: "اجازهٔ ارائه خدمت در شعبه",
        fields: [
          select("offeringId", "خدمت شعبه", offerings, (r) =>
            serviceName(r.serviceId),
          ),
          select("assignmentId", "عضویت", memberRows, memberName),
          select(
            "qualificationId",
            "صلاحیت تأییدشده",
            qRows.filter((r) => r.active && r.verified_at),
            qName,
          ),
          field("active", "ارائهٔ این خدمت مجاز است", "checkbox"),
        ],
        save: async (v, k) => {
          await wf(
            "eligibility.set",
            "admin/branches/" + branch + "/offering-staff-eligibility",
            {
              offeringId: v.offeringId,
              assignmentId: v.assignmentId,
              qualificationId: v.qualificationId,
              active: v.active === true,
            },
            k,
            "PUT",
          );
        },
      },
      link: {
        title: "اتصال هویت تأییدشده",
        fields: [
          select("staffId", "عضو تیم", staff),
          select("userId", "هویت تأییدشدهٔ موجود", rows("identities"), (r) =>
            text(r.name),
          ),
          field("evidenceReference", "مرجع تأیید ارتباط", "textarea"),
        ],
        save: async (v, k) => {
          await wf(
            "staff.link",
            "admin/staff/" + v.staffId + "/verified-identity",
            { userId: v.userId, evidenceReference: v.evidenceReference },
            k,
          );
        },
      },
    };
    open(configs[kind]);
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
  function scheduleTool(kind: string) {
    const base = "admin/branches/" + branch,
      assignmentName = (r: Row) =>
        staffName(r.staff_id) + " · " + text(r.valid_from),
      qName = (r: Row) =>
        staffName(r.staff_id) + " · " + serviceName(r.service_id),
      config = rows("configuration")[0];
    const configs: Record<string, Editor> = {
      hours: {
        title: "جایگزینی ساعات کاری شعبه",
        fields: [
          field("weekdays", "روزهای هفته", "multi", { options: weekdays }),
          field("start", "شروع", "time"),
          field("end", "پایان", "time"),
          field("validFrom", "شروع اعتبار (میلادی)", "date"),
          field("validTo", "پایان اعتبار (میلادی)", "date", {
            required: false,
          }),
          field("reason", "دلیل تغییر", "textarea"),
          field(
            "replace",
            "ساعات روزهای انتخاب‌شده جایگزین شوند؛ سایر روزها حفظ می‌شوند.",
            "checkbox",
            { required: true },
          ),
        ],
        save: async (v, k) => {
          if (!Array.isArray(v.weekdays) || !v.weekdays.length)
            throw Error("حداقل یک روز را انتخاب کنید.");
          const days = v.weekdays.map(Number);
          const kept = rows("hours")
            .filter((r) => !days.includes(Number(r.iso_weekday)))
            .map((r) => ({
              isoWeekday: Number(r.iso_weekday),
              startMinute: Number(r.start_minute),
              endMinute: Number(r.end_minute),
              validFrom: r.valid_from,
              validTo: r.valid_to ?? null,
            }));
          await wf(
            "hours.replace",
            base + "/working-hours",
            {
              segments: [
                ...kept,
                ...days.map((isoWeekday) => ({
                  isoWeekday,
                  startMinute: toMinute(v.start),
                  endMinute: toMinute(v.end),
                  validFrom: v.validFrom,
                  validTo: v.validTo || null,
                })),
              ],
              reason: v.reason,
            },
            k,
            "PUT",
          );
        },
      },
      resource: {
        title: "افزودن منبع فیزیکی",
        fields: [
          field("kind", "نوع منبع", "select", { options: physical }),
          field("label", "نام یا شناسهٔ واقعی منبع"),
          field("active", "منبع در دسترس است", "checkbox"),
        ],
        save: async (v, k) => {
          await wf(
            "resource.create",
            base + "/resources",
            { kind: v.kind, label: v.label, active: v.active === true },
            k,
          );
        },
      },
      rule: {
        title: "الگوی تکرار شیفت",
        fields: [
          select("staffId", "عضو تیم", staff),
          select("assignmentId", "عضویت", rows("assignments"), assignmentName),
          select(
            "qualificationId",
            "صلاحیت تأییدشده",
            rows("qualifications").filter((r) => r.active && r.verified_at),
            qName,
          ),
          select(
            "offeringId",
            "خدمت مشخص (اختیاری)",
            offerings,
            (r) => serviceName(r.serviceId),
            false,
          ),
          field("weekday", "روز هفته", "select", { options: weekdays }),
          field("start", "شروع", "time"),
          field("end", "پایان", "time"),
          field("validFrom", "شروع اعتبار (میلادی)", "date"),
          field("validTo", "پایان اعتبار (میلادی)", "date", {
            required: false,
          }),
        ],
        save: async (v, k) => {
          await wf(
            "rule.create",
            base + "/schedule-rules",
            {
              staffId: v.staffId,
              assignmentId: v.assignmentId,
              qualificationId: v.qualificationId,
              offeringId: v.offeringId || null,
              isoWeekday: Number(v.weekday),
              startMinute: toMinute(v.start),
              endMinute: toMinute(v.end),
              validFrom: v.validFrom,
              validTo: v.validTo || null,
            },
            k,
            "PUT",
          );
        },
      },
      publish: {
        title: "انتشار شیفت از الگوی تأییدشده",
        fields: [
          select(
            "rule",
            "الگوی شیفت",
            rows("rules"),
            (r) =>
              staffName(r.staff_id) +
              " · " +
              (weekdays.find((d) => Number(d.value) === Number(r.iso_weekday))
                ?.label ?? "") +
              " " +
              minute(r.start_minute) +
              "–" +
              minute(r.end_minute),
          ),
          field("date", "تاریخ انتشار (میلادی)", "date"),
          field("reason", "دلیل انتشار", "textarea"),
          field(
            "reviewed",
            "عضویت، ساعات و صلاحیت را بررسی کرده‌ام.",
            "checkbox",
            { required: true },
          ),
        ],
        save: async (v, k) => {
          const r = rows("rules").find((r) => r.id === v.rule)!;
          await wf(
            "schedule.publish",
            base + "/schedule/publications",
            {
              staffId: r.staff_id,
              segments: [
                {
                  ruleId: r.id,
                  ruleVersion: text(r.configurationVersion ?? r.recordVersion),
                  date: v.date,
                  startResolution: "reject",
                  endResolution: "reject",
                },
              ],
              replaces: [],
              reason: v.reason,
              overnight: false,
            },
            k,
          );
        },
      },
      timeoff: {
        title: "ثبت مرخصی برای بررسی",
        fields: [
          select("staffId", "عضو تیم", staff),
          field("start", "شروع به وقت شعبه", "datetime-local"),
          field("end", "پایان به وقت شعبه", "datetime-local"),
          field("reason", "دلیل", "textarea"),
        ],
        save: async (v, k) => {
          await wf(
            "timeoff.create",
            base + "/time-off",
            {
              staffId: v.staffId,
              startsAt: await instant(v.start),
              endsAt: await instant(v.end),
              reason: v.reason,
            },
            k,
          );
        },
      },
      closure: {
        title: "ثبت تعطیلی شعبه برای بررسی",
        fields: [
          field("start", "شروع به وقت شعبه", "datetime-local"),
          field("end", "پایان به وقت شعبه", "datetime-local"),
          field("reason", "دلیل", "textarea"),
        ],
        save: async (v, k) => {
          await wf(
            "closure.create",
            base + "/closures",
            {
              startsAt: await instant(v.start),
              endsAt: await instant(v.end),
              reason: v.reason,
            },
            k,
          );
        },
      },
      configuration: {
        title: "تنظیم ظرفیت و مهلت‌ها",
        fields: [
          field("slotStrideMinutes", "گام نمایش زمان (دقیقه)", "number", {
            min: 1,
          }),
          field("leadMinutes", "حداقل فاصله تا شروع (دقیقه)", "number", {
            min: 0,
          }),
          field("horizonDays", "افق نمایش (روز)", "number", { min: 1 }),
          field("holdTtlSeconds", "مهلت نگه‌داری (ثانیه)", "number", {
            min: 1,
          }),
          field("quoteTtlSeconds", "اعتبار پیشنهاد (ثانیه)", "number", {
            min: 60,
            max: 3600,
          }),
        ],
        initial: config
          ? {
              slotStrideMinutes: text(config.slot_stride_minutes),
              leadMinutes: text(config.lead_minutes),
              horizonDays: text(config.horizon_days),
              holdTtlSeconds: text(config.hold_ttl_seconds),
              quoteTtlSeconds: text(config.quote_ttl_seconds),
            }
          : {},
        save: async (v, k) => {
          await wf(
            "configuration.set",
            base + "/availability-configuration",
            Object.fromEntries(
              Object.entries(v).map(([key, val]) => [key, Number(val)]),
            ),
            k,
            "PUT",
          );
        },
      },
      enable: {
        title: "بررسی و فعال‌سازی رزرو شعبه",
        fields: [
          field("offerings", "خدمات مورد تأیید برای فعال‌سازی", "multi", {
            options: options(offerings, (r) => serviceName(r.serviceId)),
          }),
          field(
            "confirmed",
            "پیکربندی، تعرفه، منابع و سیاست‌ها را تأیید می‌کنم.",
            "checkbox",
            { required: true },
          ),
        ],
        save: async (v, k) => {
          if (!Array.isArray(v.offerings) || !v.offerings.length)
            throw Error("حداقل یک خدمت انتخاب کنید.");
          await api("booking/commands/configuration.enable", {
            method: "POST",
            key: k,
            data: { branchId: branch, offeringIds: v.offerings },
          });
          notify("سرور وجود یک برنامهٔ واقعی قابل رزرو را بررسی و تأیید کرد.");
        },
      },
    };
    open(configs[kind]);
  }
  function reviewException(r: Row) {
    open({
      title: "بررسی " + (r.kind === "closures" ? "تعطیلی" : "مرخصی"),
      fields: [
        field("approve", "نتیجهٔ بررسی", "select", {
          options: [
            { value: "true", label: "تأیید" },
            { value: "false", label: "رد" },
          ],
        }),
        field("reason", "دلیل تصمیم", "textarea"),
      ],
      save: async (v, k) => {
        await wf(
          "review",
          "admin/branches/" +
            branch +
            "/" +
            (r.kind === "closures" ? "closures" : "time-off") +
            "/" +
            r.id +
            "/review",
          { approve: v.approve === "true", reason: v.reason },
          k,
        );
      },
    });
  }
  async function showReservation(r: Row) {
    setError("");
    setDetail(undefined);
    setEditor(undefined);
    try {
      setDetail(
        await api<Row>(
          "admin/portal/read/reservation" +
            query({ branchId: branch, entityId: r.id }),
        ),
      );
    } catch (e) {
      setError((e as Error).message);
      requestAnimationFrame(() => errorRef.current?.focus());
    }
  }
  function cancelReservation(r: Row) {
    open({
      title: "تأیید لغو رزرو",
      fields: [
        field("reason", "دلیل لغو توسط مدیر", "textarea", {
          help: "دلیل در سابقهٔ خصوصی رزرو ثبت می‌شود.",
        }),
        field(
          "confirmed",
          "شرایط پذیرفته‌شده و آزاد شدن ظرفیت را بررسی کرده‌ام.",
          "checkbox",
          { required: true },
        ),
      ],
      save: async (v, k) => {
        await write(
          "booking.cancel",
          r.id,
          text(r.version),
          { reason: v.reason, confirmed: v.confirmed === true },
          k,
        );
      },
    });
  }
  function resourceEdit(r: Row) {
    open({
      title: "ویرایش منبع فیزیکی",
      fields: [
        field("label", "نام منبع"),
        field("active", "منبع فعال است", "checkbox"),
      ],
      initial: initial(r, ["label", "active"]),
      save: async (v, k) => {
        await wf(
          "resource.update",
          "admin/branches/" + branch + "/resources/" + r.id,
          { label: v.label, active: v.active === true },
          k,
          "PUT",
        );
      },
    });
  }
  const available = tabs.filter((t) =>
    t[0] === "overview"
      ? actor?.assignments.some((x) =>
          ["business.read", "media.manage", "booking.read"].includes(
            x.permission,
          ),
        )
      : can(t[2]) || actor?.assignments.some((x) => x.permission === t[2]),
  );
  const title = tabs.find((t) => t[0] === view)?.[1] ?? "نمای کلی",
    reservations = rows("reservations");
  return (
    <div className="admin-app">
      <a href="#admin-content" className="skip-link">
        رفتن به محتوای پنل
      </a>
      <aside
        ref={sidebarRef}
        role={mobileMenu ? "dialog" : undefined}
        aria-modal={mobileMenu ? true : undefined}
        className={"admin-sidebar" + (mobileMenu ? " is-open" : "")}
        aria-label="ناوبری مدیریت"
      >
        <a className="admin-brand" href="/">
          <svg
            width="35"
            height="35"
            viewBox="0 0 32 32"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.3"
            aria-hidden="true"
          >
            <path d="m5 10 6 5 5-9 5 9 6-5-3 15H8z" />
          </svg>
          <span>
            <strong>محمد استایل</strong>
            <small>مدیریت سالن</small>
          </span>
        </a>
        <button className="admin-button admin-drawer-close" onClick={closeMenu}>
          بستن منوی مدیریت
        </button>
        <div className="admin-nav-caption">فضای مدیریت</div>
        <nav id="admin-navigation">
          {available.map(([id, label]) => (
            <a
              key={id}
              href={"/admin?view=" + id}
              aria-current={view === id ? "page" : undefined}
              onClick={(e) => {
                e.preventDefault();
                navigate(id);
              }}
            >
              <Icon kind={id} />
              {label}
            </a>
          ))}
        </nav>
        <div className="admin-sidebar-footer">
          <a href="/portfolio">مشاهدهٔ گالری عمومی ↗</a>
          <a href="/booking?mode=server">مسیر رزرو SERVER ↗</a>
          <a href="/booking">مسیر رزرو DEMO ↗</a>
          <a href="/">بازگشت به خانه</a>
          {actor && (
            <button
              className="admin-button"
              onClick={async () => {
                try {
                  await api("session/revoke", {
                    method: "POST",
                    data: {},
                    key: crypto.randomUUID(),
                  });
                  setWorkspace(undefined);
                  setError(
                    "نشست پایان یافت. برای ورود دوباره از ابزار محلی نشست استفاده کنید.",
                  );
                } catch (e) {
                  setError((e as Error).message);
                }
              }}
            >
              پایان نشست
            </button>
          )}
        </div>
      </aside>
      <div className="admin-main" inert={mobileMenu}>
        <header className="admin-header">
          <div>
            <div className="admin-eyebrow">MOHAMMAD STYLE / OPERATIONS</div>
            <h1>{title}</h1>
            <p>
              {workspace?.business.items[0]
                ? text(workspace.business.items[0].brandName)
                : "پنل مدیریت محمد استایل"}
            </p>
          </div>
          <div className="admin-header-actions">
            <span className="admin-session">
              {actor ? "نشست معتبر" : "ورود لازم است"}
            </span>
            <button
              ref={menuRef}
              className="admin-button admin-menu-button"
              aria-expanded={mobileMenu}
              aria-controls="admin-navigation"
              onClick={() => setMobileMenu((x) => !x)}
            >
              {mobileMenu ? "بستن منو" : "منوی مدیریت"}
            </button>
          </div>
        </header>
        <main id="admin-content" tabIndex={-1} className="admin-content">
          <div className="admin-environment">
            <strong>محیط آزمایشی جداگانه</strong>
            <span>
              دادهٔ تجاری تأییدنشده را وارد نکنید. پرداخت و پیامک واقعی فعال
              نیست.
            </span>
          </div>
          {error && (
            <div
              role="alert"
              tabIndex={-1}
              ref={errorRef}
              className="admin-error"
            >
              <p>{error}</p>
              <button className="admin-button" onClick={refresh}>
                تلاش دوباره
              </button>
              <p className="admin-muted">
                ورود آزمایشی فقط با نشست تأییدشدهٔ ابزار محلی ممکن است؛ ورود
                تولیدی پیاده‌سازی نشده است.
              </p>
            </div>
          )}
          {actor && (
            <div className="admin-toolbar">
              <label>
                شعبه
                <select
                  value={scope ? "all" : (branch ?? "")}
                  onChange={(e) => {
                    setScope(e.target.value === "all");
                    setBranch(e.target.value === "all" ? null : e.target.value);
                    setOffset(0);
                    setEditor(undefined);
                    setDetail(undefined);
                  }}
                >
                  {view === "media" && can("media.manage", null) && (
                    <option value="all">رسانهٔ کل مجموعه</option>
                  )}
                  {branches.map((b) => (
                    <option key={b.id} value={b.id}>
                      {name(b)}
                    </option>
                  ))}
                </select>
              </label>
              <div className="admin-toolbar-actions">
                <span className="admin-muted">
                  {currentBranch
                    ? text(currentBranch.timeZone)
                    : "محدودهٔ مجموعه"}
                </span>
                <button
                  className="admin-button"
                  onClick={refresh}
                  disabled={loading}
                >
                  تازه‌سازی
                </button>
              </div>
            </div>
          )}
          <div role="status" className="admin-feedback">
            {loading ? "در حال دریافت دادهٔ مجاز از سرور…" : toast}
          </div>
          {!loading && !error && actor && (
            <>
              {editor && (
                <AdminForm
                  key={editor.title + text(editor.initial?.id) + revision}
                  {...editor}
                  cancel={() => setEditor(undefined)}
                />
              )}
              {view === "overview" && (
                <>
                  <div className="admin-metrics">
                    {[
                      ["شعبهٔ در دسترس", branches.length],
                      ["خدمت ثبت‌شده", services.length],
                      ["رزرو در این صفحه", reservations.length],
                      ["رسانه در این صفحه", rows("media").length],
                    ].map(([label, count]) => (
                      <section key={label} className="admin-metric">
                        <small>{label}</small>
                        <strong>
                          {new Intl.NumberFormat("fa-IR").format(Number(count))}
                        </strong>
                        <span>دادهٔ واقعیِ محیط انتخاب‌شده</span>
                      </section>
                    ))}
                  </div>
                  <div className="admin-overview-grid">
                    <section className="admin-panel">
                      <div className="admin-section-head">
                        <h2>آخرین رزروها</h2>
                        <button
                          className="admin-text-button"
                          onClick={() => navigate("reservations")}
                        >
                          مشاهدهٔ سابقه
                        </button>
                      </div>
                      {reservations.length ? (
                        <div className="admin-list">
                          {reservations.slice(0, 5).map((r) => (
                            <button
                              key={r.id}
                              className="admin-reservation-row"
                              onClick={() => {
                                navigate("reservations");
                                void showReservation(r);
                              }}
                            >
                              <span>
                                {text(r.customerName)}
                                <small>
                                  {dateTime(
                                    (
                                      r.quote as {
                                        content?: { startsAt: string };
                                      }
                                    )?.content?.startsAt,
                                    zone,
                                  )}
                                </small>
                              </span>
                              <Status value={text(r.status)} />
                            </button>
                          ))}
                        </div>
                      ) : (
                        <Empty>هنوز رزروی در این شعبه وجود ندارد.</Empty>
                      )}
                    </section>
                    <section className="admin-panel">
                      <h2>وضعیت رزروهای این صفحه</h2>
                      <p className="admin-muted">
                        این شمارش فقط از رکوردهای بارگذاری‌شده محاسبه می‌شود.
                      </p>
                      <div className="admin-status-bars">
                        {[
                          "CONFIRMED",
                          "HELD",
                          "PENDING_PAYMENT",
                          "CANCELLED",
                          "EXPIRED",
                        ].map((s) => {
                          const n = reservations.filter(
                            (r) => r.status === s,
                          ).length;
                          return (
                            <div key={s}>
                              <span>{statuses[s]}</span>
                              <div>
                                <i
                                  style={{
                                    width: reservations.length
                                      ? (100 * n) / reservations.length + "%"
                                      : "0%",
                                  }}
                                />
                              </div>
                              <b>{n.toLocaleString("fa-IR")}</b>
                            </div>
                          );
                        })}
                      </div>
                    </section>
                  </div>
                  <section className="admin-panel">
                    <h2>پیش از فعال‌سازی رزرو</h2>
                    <p>
                      تعرفه، زمان‌ها، منابع، عضویت و صلاحیت تیم، ساعت کاری و
                      نسخهٔ سیاست باید تأیید شده باشند. سرور فقط پس از یافتن
                      برنامهٔ قابل اجرا، رزرو را فعال می‌کند.
                    </p>
                    <button
                      className="admin-button"
                      onClick={() => navigate("schedule")}
                    >
                      بررسی پیکربندی شعبه
                    </button>
                  </section>
                </>
              )}
              {view === "branches" && (
                <section className="admin-panel">
                  <div className="admin-section-head">
                    <h2>شعبه‌های ثبت‌شده</h2>
                    {can("branch.manage", null) && (
                      <button
                        className="admin-button admin-primary"
                        onClick={() => branchForm()}
                      >
                        افزودن شعبه
                      </button>
                    )}
                  </div>
                  <div className="admin-record-grid">
                    {branches.map((b) => (
                      <article key={b.id} className="admin-record">
                        <div>
                          <Icon kind="branches" />
                          <h3>{name(b)}</h3>
                        </div>
                        <p>
                          {text(b.address) ||
                            "نشانی هنوز ثبت یا تأیید نشده است."}
                        </p>
                        <dl>
                          <dt>منطقهٔ زمانی</dt>
                          <dd dir="ltr">{text(b.timeZone)}</dd>
                          <dt>وضعیت</dt>
                          <dd>
                            {b.active ? "فعال" : "غیرفعال"} ·{" "}
                            {b.bookable ? "رزرو فعال" : "رزرو غیرفعال"}
                          </dd>
                        </dl>
                        {can("branch.manage", b.id) && (
                          <button
                            className="admin-button"
                            onClick={() => branchForm(b)}
                          >
                            ویرایش شعبه
                          </button>
                        )}
                      </article>
                    ))}
                  </div>
                  {!branches.length && (
                    <Empty>
                      شعبه‌ای ثبت نشده است. مشخصات واقعی را پس از تأیید وارد
                      کنید.
                    </Empty>
                  )}
                </section>
              )}
              {view === "services" && (
                <section className="admin-panel">
                  <div className="admin-section-head">
                    <h2>فهرست خدمات</h2>
                    {can("catalog.manage", null) && (
                      <button
                        className="admin-button admin-primary"
                        onClick={() => serviceForm()}
                      >
                        افزودن خدمت
                      </button>
                    )}
                  </div>
                  <p className="admin-muted">
                    این فهرست عملیاتی است؛ شش خدمت بروشور و طراحی Homepage
                    به‌صورت خودکار تغییر نمی‌کنند.
                  </p>
                  <div className="admin-list">
                    {services.map((s) => (
                      <article key={s.id} className="admin-list-row">
                        <div>
                          <h3>{name(s)}</h3>
                          <p>{text(s.description) || "توضیحی ثبت نشده است."}</p>
                        </div>
                        <span className="admin-tag">
                          {s.active ? "فعال" : "غیرفعال"}
                        </span>
                        {can("catalog.manage", null) && (
                          <button
                            className="admin-button"
                            onClick={() => serviceForm(s)}
                          >
                            ویرایش خدمت
                          </button>
                        )}
                      </article>
                    ))}
                  </div>
                  {!services.length && <Empty>خدمتی ثبت نشده است.</Empty>}
                </section>
              )}
              {view === "prices" && (
                <section className="admin-panel">
                  <div className="admin-section-head">
                    <h2>تعرفهٔ همین شعبه</h2>
                    {can("offering.manage") && branch && (
                      <button
                        className="admin-button admin-primary"
                        onClick={() =>
                          open({
                            title: "افزودن خدمت به شعبه",
                            fields: [
                              select(
                                "serviceId",
                                "خدمت",
                                services.filter(
                                  (s) =>
                                    !offerings.some(
                                      (o) => o.serviceId === s.id,
                                    ),
                                ),
                              ),
                            ],
                            save: async (v, k) => {
                              await write(
                                "offering.create",
                                null,
                                "0",
                                { serviceId: v.serviceId },
                                k,
                              );
                            },
                          })
                        }
                      >
                        افزودن خدمت به شعبه
                      </button>
                    )}
                  </div>
                  <p className="admin-muted">
                    واحد ذخیره‌سازی ریال است. مبالغ و زمان‌های نامشخص قابل رزرو
                    نیستند. تغییر قیمت، شرایط رزروهای قبلی را عوض نمی‌کند.
                  </p>
                  <div className="admin-record-grid">
                    {offerings.map((o) => (
                      <article key={o.id} className="admin-record">
                        <h3>{serviceName(o.serviceId)}</h3>
                        <strong className="admin-price">
                          {money(
                            (o.price as { amountRial?: string })?.amountRial,
                          )}
                        </strong>
                        <p>
                          {text(o.durationMinutes) || "نامشخص"} دقیقه ·
                          آماده‌سازی {text(o.bufferBeforeMinutes) || "نامشخص"} /{" "}
                          {text(o.bufferAfterMinutes) || "نامشخص"} دقیقه
                        </p>
                        <p className="admin-muted">
                          {o.active ? "ارائهٔ فعال" : "ارائهٔ غیرفعال"} ·{" "}
                          {o.resourcesConfirmed
                            ? "منابع تأییدشده"
                            : "منابع تأیید نشده"}
                        </p>
                        <ul>
                          {(
                            (o.resourceRequirements as {
                              kind: string;
                              quantity: number;
                            }[]) ?? []
                          ).map((r) => (
                            <li key={r.kind}>
                              {physical.find((p) => p.value === r.kind)?.label}:{" "}
                              {r.quantity}
                            </li>
                          ))}
                        </ul>
                        {can("offering.manage") && (
                          <div className="admin-row-actions">
                            <button
                              className="admin-button"
                              onClick={() => priceForm(o)}
                            >
                              ویرایش تعرفه و زمان
                            </button>
                            <button
                              className="admin-button"
                              onClick={() =>
                                open({
                                  title:
                                    "نیازمندی منبع · " +
                                    serviceName(o.serviceId),
                                  fields: [
                                    field("kind", "نوع منبع", "select", {
                                      options: physical,
                                    }),
                                    field(
                                      "quantity",
                                      "تعداد واحد لازم",
                                      "number",
                                      { min: 1, max: 16 },
                                    ),
                                    field(
                                      "confirmed",
                                      "تعداد منابع واقعی را بررسی و تأیید کرده‌ام.",
                                      "checkbox",
                                      { required: true },
                                    ),
                                  ],
                                  save: async (v, k) => {
                                    await write(
                                      "offering.requirements",
                                      o.id,
                                      text(o.version),
                                      {
                                        kind: v.kind,
                                        quantity: Number(v.quantity),
                                        confirmed: v.confirmed === true,
                                      },
                                      k,
                                    );
                                  },
                                })
                              }
                            >
                              تعیین منابع لازم
                            </button>
                          </div>
                        )}
                      </article>
                    ))}
                  </div>
                  {!offerings.length && (
                    <Empty>برای این شعبه خدمتی پیکربندی نشده است.</Empty>
                  )}
                </section>
              )}
              {view === "staff" && (
                <>
                  <section className="admin-panel">
                    <div className="admin-section-head">
                      <h2>تیم سالن</h2>
                      {can("staff.manage", null) && (
                        <button
                          className="admin-button admin-primary"
                          onClick={() => staffForm()}
                        >
                          افزودن عضو تیم
                        </button>
                      )}
                    </div>
                    <div className="admin-list">
                      {staff.map((s) => (
                        <article key={s.id} className="admin-list-row">
                          <div>
                            <h3>{name(s)}</h3>
                            <p>{s.active ? "فعال" : "غیرفعال"}</p>
                          </div>
                          {can("staff.manage", null) && (
                            <button
                              className="admin-button"
                              onClick={() => staffForm(s)}
                            >
                              ویرایش عضو
                            </button>
                          )}
                        </article>
                      ))}
                    </div>
                    {!staff.length && (
                      <Empty>
                        عضوی ثبت نشده است. نام و صلاحیت واقعی باید تأیید شوند.
                      </Empty>
                    )}
                  </section>
                  <section className="admin-panel">
                    <h2>عضویت و صلاحیت</h2>
                    <div className="admin-row-actions">
                      {can("staff.manage") && (
                        <>
                          <button
                            className="admin-button"
                            onClick={() => staffTool("assignment")}
                          >
                            عضویت در شعبه
                          </button>
                          <button
                            className="admin-button"
                            onClick={() => staffTool("close")}
                          >
                            پایان عضویت
                          </button>
                        </>
                      )}
                      {can("staff.qualify", null) && (
                        <button
                          className="admin-button"
                          onClick={() => staffTool("qualification")}
                        >
                          تأیید صلاحیت خدمت
                        </button>
                      )}
                      {can("schedule.manage") && (
                        <button
                          className="admin-button"
                          onClick={() => staffTool("eligibility")}
                        >
                          اجازهٔ ارائه خدمت
                        </button>
                      )}
                      {can("staff.link", null) && (
                        <button
                          className="admin-button"
                          onClick={() => staffTool("link")}
                        >
                          اتصال هویت تأییدشده
                        </button>
                      )}
                    </div>
                    <div className="admin-list">
                      {rows("assignments").map((r) => (
                        <div className="admin-list-row" key={r.id}>
                          <span>{staffName(r.staff_id)}</span>
                          <span>
                            {text(r.valid_from)} تا{" "}
                            {text(r.valid_to) || "بدون پایان ثبت‌شده"}
                          </span>
                          <span className="admin-tag">
                            {r.active ? "فعال" : "غیرفعال"}
                          </span>
                        </div>
                      ))}
                    </div>
                  </section>
                </>
              )}
              {view === "schedule" && (
                <>
                  <section className="admin-panel">
                    <div className="admin-section-head">
                      <h2>تقویم کاری شعبه</h2>
                      <label>
                        از تاریخ (میلادی)
                        <input
                          type="date"
                          value={from}
                          onChange={(e) => {
                            if (e.target.value) setFrom(e.target.value);
                          }}
                        />
                      </label>
                    </div>
                    <div className="admin-calendar-controls">
                      <button
                        className="admin-button"
                        onClick={() => setFrom(addDays(from, -7))}
                      >
                        هفتهٔ قبل
                      </button>
                      <button
                        className="admin-button"
                        onClick={() => setFrom(addDays(from, 7))}
                      >
                        هفتهٔ بعد
                      </button>
                      {can("schedule.history.read") && (
                        <label className="admin-check">
                          <input
                            type="checkbox"
                            checked={history}
                            onChange={(e) => setHistory(e.target.checked)}
                          />
                          نمایش سابقهٔ تقویم
                        </label>
                      )}
                    </div>
                    <div className="admin-calendar">
                      {Array.from({ length: 7 }, (_, i) =>
                        addDays(from, i),
                      ).map((day) => {
                        const shifts = rows("calendar").filter(
                          (r) =>
                            text(r.local_date) === day ||
                            text(r.starts_at).slice(0, 10) === day,
                        );
                        return (
                          <section key={day} className="admin-day">
                            <h3>
                              {new Intl.DateTimeFormat("fa-IR", {
                                timeZone: "UTC",
                                weekday: "long",
                                month: "short",
                                day: "numeric",
                              }).format(new Date(day + "T12:00Z"))}
                            </h3>
                            {shifts.length ? (
                              shifts.map((r) => (
                                <article
                                  className={
                                    "admin-shift" +
                                    (r.evidenceState === "PUBLISHED"
                                      ? ""
                                      : " admin-shift-history")
                                  }
                                  key={r.id}
                                >
                                  <strong>{staffName(r.staff_id)}</strong>
                                  <time>
                                    {dateTime(r.starts_at, zone)} تا{" "}
                                    {dateTime(r.ends_at, zone)}
                                  </time>
                                  <small>
                                    {r.evidenceState === "PUBLISHED"
                                      ? "منتشرشده"
                                      : text(r.evidenceState) === "WITHDRAWN"
                                        ? "پس‌گرفته‌شده"
                                        : "پیش‌نویس"}
                                  </small>
                                  {can("schedule.publish") &&
                                    r.evidenceState === "PUBLISHED" && (
                                      <button
                                        className="admin-text-button"
                                        onClick={() =>
                                          open({
                                            title: "پس‌گرفتن شیفت",
                                            fields: [
                                              field(
                                                "reason",
                                                "دلیل",
                                                "textarea",
                                              ),
                                              field(
                                                "confirmed",
                                                "اثر این تغییر را بررسی کرده‌ام.",
                                                "checkbox",
                                                { required: true },
                                              ),
                                            ],
                                            save: async (v, k) => {
                                              await wf(
                                                "schedule.withdraw",
                                                "admin/branches/" +
                                                  branch +
                                                  "/schedule/withdrawals",
                                                {
                                                  staffId: r.staff_id,
                                                  shiftIds: [r.id],
                                                  reason: v.reason,
                                                },
                                                k,
                                              );
                                            },
                                          })
                                        }
                                      >
                                        پس‌گرفتن شیفت
                                      </button>
                                    )}
                                </article>
                              ))
                            ) : (
                              <span className="admin-muted">
                                شیفتی منتشر نشده است.
                              </span>
                            )}
                          </section>
                        );
                      })}
                    </div>
                  </section>
                  <section className="admin-panel">
                    <h2>پیکربندی و برنامه‌ریزی</h2>
                    <div className="admin-row-actions">
                      {can("branchhours.manage") && (
                        <button
                          className="admin-button"
                          onClick={() => scheduleTool("hours")}
                        >
                          ساعات کاری شعبه
                        </button>
                      )}
                      {can("resource.manage") && (
                        <button
                          className="admin-button"
                          onClick={() => scheduleTool("resource")}
                        >
                          افزودن منبع فیزیکی
                        </button>
                      )}
                      {can("schedule.manage") && (
                        <>
                          <button
                            className="admin-button"
                            onClick={() => scheduleTool("rule")}
                          >
                            الگوی تکرار شیفت
                          </button>
                          <button
                            className="admin-button"
                            onClick={() => scheduleTool("timeoff")}
                          >
                            ثبت مرخصی
                          </button>
                          <button
                            className="admin-button"
                            onClick={() => scheduleTool("closure")}
                          >
                            ثبت تعطیلی
                          </button>
                          <button
                            className="admin-button"
                            onClick={() => scheduleTool("configuration")}
                          >
                            تنظیم ظرفیت و مهلت‌ها
                          </button>
                        </>
                      )}
                      {can("schedule.publish") && (
                        <button
                          className="admin-button"
                          onClick={() => scheduleTool("publish")}
                        >
                          انتشار شیفت
                        </button>
                      )}
                      {can("booking.configure") && (
                        <button
                          className="admin-button admin-primary"
                          onClick={() => scheduleTool("enable")}
                        >
                          بررسی و فعال‌سازی رزرو
                        </button>
                      )}
                    </div>
                    <h3>ساعات و منابع ثبت‌شده</h3>
                    <div className="admin-list">
                      {rows("hours").map((r) => (
                        <div className="admin-list-row" key={r.id}>
                          <span>
                            {
                              weekdays.find(
                                (w) =>
                                  Number(w.value) === Number(r.iso_weekday),
                              )?.label
                            }
                          </span>
                          <span dir="ltr">
                            {minute(r.start_minute)}–{minute(r.end_minute)}
                          </span>
                          <span>
                            {text(r.valid_from)} تا{" "}
                            {text(r.valid_to) || "بدون پایان"}
                          </span>
                        </div>
                      ))}
                      {rows("resources").map((r) => (
                        <div className="admin-list-row" key={r.id}>
                          <span>
                            {text(r.label)} ·{" "}
                            {physical.find((p) => p.value === r.kind)?.label}
                          </span>
                          <span>{r.active ? "فعال" : "غیرفعال"}</span>
                          {can("resource.manage") && (
                            <button
                              className="admin-button"
                              onClick={() => resourceEdit(r)}
                            >
                              ویرایش منبع
                            </button>
                          )}
                        </div>
                      ))}
                    </div>
                    <h3>مرخصی و تعطیلی</h3>
                    {rows("exceptions").length ? (
                      <div className="admin-list">
                        {rows("exceptions").map((r) => (
                          <div className="admin-list-row" key={r.id}>
                            <span>
                              {r.kind === "closures"
                                ? "تعطیلی شعبه"
                                : staffName(r.staff_id)}
                              <small>
                                {dateTime(r.starts_at, zone)} تا{" "}
                                {dateTime(r.ends_at, zone)}
                              </small>
                            </span>
                            <Status value={text(r.review_status)} />
                            {can("timeoff.approve") &&
                              ["REQUESTED", "LEGACY_UNREVIEWED"].includes(
                                text(r.review_status),
                              ) && (
                                <button
                                  className="admin-button"
                                  onClick={() => reviewException(r)}
                                >
                                  بررسی درخواست
                                </button>
                              )}
                          </div>
                        ))}
                      </div>
                    ) : (
                      <Empty>در این بازه استثنایی ثبت نشده است.</Empty>
                    )}
                  </section>
                </>
              )}
              {view === "policies" && (
                <PolicyPanel
                  data={data}
                  branch={branch}
                  zone={zone}
                  services={services}
                  staff={staff}
                  can={can}
                  open={open}
                  notify={notify}
                />
              )}
              {view === "reservations" && (
                <>
                  <section className="admin-panel">
                    <div className="admin-section-head">
                      <h2>رزروها و وضعیت‌ها</h2>
                      <span className="admin-muted">
                        پرداخت و بازپرداخت واقعی انجام نمی‌شود.
                      </span>
                    </div>
                    {reservations.length ? (
                      <div className="admin-list">
                        {reservations.map((r) => (
                          <article
                            key={r.id}
                            data-booking-id={r.id}
                            className="admin-list-row"
                          >
                            <div>
                              <h3>{text(r.customerName) || "مشتری"}</h3>
                              <p>
                                {(
                                  (
                                    r.quote as {
                                      content?: {
                                        items: { displayName: string }[];
                                      };
                                    }
                                  )?.content?.items ?? []
                                )
                                  .map((i) => i.displayName)
                                  .join("، ") || "پیش‌نویس بدون برنامه"}
                              </p>
                              <small>
                                {dateTime(
                                  (
                                    r.quote as {
                                      content?: { startsAt: string };
                                    }
                                  )?.content?.startsAt,
                                  zone,
                                )}
                              </small>
                            </div>
                            <Status value={text(r.status)} />
                            <button
                              className="admin-button"
                              onClick={() => showReservation(r)}
                            >
                              جزئیات و سابقه
                            </button>
                          </article>
                        ))}
                      </div>
                    ) : (
                      <Empty>رزروی در این صفحه وجود ندارد.</Empty>
                    )}
                    <Pagination
                      offset={offset}
                      count={reservations.length}
                      size={25}
                      change={setOffset}
                    />
                  </section>
                  {detail && (
                    <section className="admin-panel">
                      <div className="admin-section-head">
                        <h2>جزئیات رزرو · {text(detail.customerName)}</h2>
                        <button
                          className="admin-button"
                          onClick={() => setDetail(undefined)}
                        >
                          بستن جزئیات
                        </button>
                      </div>
                      <Status value={text(detail.status)} />
                      <p>
                        مبلغ پذیرفته‌شده:{" "}
                        {money(
                          (detail.quote as { content?: { totalRial: string } })
                            ?.content?.totalRial,
                        )}
                      </p>
                      <p>
                        شرایط پذیرفته‌شده:{" "}
                        {text(
                          (
                            detail.quote as {
                              content?: {
                                policy?: { terms?: { termsText: string } };
                              };
                            }
                          )?.content?.policy?.terms?.termsText,
                        )}
                      </p>
                      <p>
                        مبالغ پرداختی و بازپرداختی واقعی: صفر؛ هیچ سامانهٔ
                        پرداختی متصل نیست.
                      </p>
                      {can("booking.manage") &&
                        (
                          detail.cancellation as {
                            cancellationAllowed?: boolean;
                          }
                        )?.cancellationAllowed && (
                          <button
                            className="admin-button admin-danger"
                            onClick={() => cancelReservation(detail)}
                          >
                            بررسی و لغو رزرو
                          </button>
                        )}
                      <ol className="admin-timeline">
                        {(
                          (detail.events as {
                            at: string;
                            from: string;
                            to: string;
                            event: string;
                            reason?: string;
                          }[]) ?? []
                        ).map((e, i) => (
                          <li key={i}>
                            <strong>{statuses[e.to] ?? e.to}</strong>
                            <time>{dateTime(e.at, zone)}</time>
                            <p>
                              {e.reason ||
                                (e.event === "mvp.booking.admin_cancel"
                                  ? "لغو توسط مدیر"
                                  : e.event === "b4.booking.expired"
                                    ? "پایان مهلت"
                                    : "رویداد مسیر رزرو")}
                            </p>
                          </li>
                        ))}
                      </ol>
                    </section>
                  )}
                </>
              )}
              {view === "media" && (
                <MediaPanel
                  items={rows("media")}
                  categories={rows("categories")}
                  branch={scope ? null : branch}
                  can={can}
                  open={open}
                  write={write}
                  notify={notify}
                />
              )}{" "}
              {view === "media" && (
                <Pagination
                  offset={offset}
                  count={rows("media").length}
                  size={25}
                  change={setOffset}
                />
              )}
            </>
          )}
        </main>
        <footer className="admin-footer">
          محمد استایل · مدیریت در محیط توسعهٔ جداگانه · نسخهٔ عمومی فقط رسانهٔ
          دارای مجوز را نمایش می‌دهد.
        </footer>
      </div>
    </div>
  );
}
export function Status({ value }: { value: string }) {
  return (
    <span className={"admin-tag admin-status-" + value.toLowerCase()}>
      {statuses[value] ?? value}
    </span>
  );
}
export function Empty({ children }: { children: React.ReactNode }) {
  return <div className="admin-empty">{children}</div>;
}
function Pagination({
  offset,
  count,
  size,
  change,
}: {
  offset: number;
  count: number;
  size: number;
  change: (n: number) => void;
}) {
  return (
    <div className="admin-pagination">
      <button
        className="admin-button"
        disabled={offset === 0}
        onClick={() => change(Math.max(0, offset - size))}
      >
        صفحهٔ قبل
      </button>
      <span>صفحهٔ {(offset / size + 1).toLocaleString("fa-IR")}</span>
      <button
        className="admin-button"
        disabled={count < size}
        onClick={() => change(offset + size)}
      >
        صفحهٔ بعد
      </button>
    </div>
  );
}
