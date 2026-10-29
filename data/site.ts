/** Source: client brochure IMG_2793.jpeg; unknown data intentionally excluded. */
export const business = {
  brand: "محمد استایل",
  brochureTitle: "سالن ممتاز پونک",
  location: "پونک، ساختمان رونیکا پالاس، لابی",
  instagram: "https://www.instagram.com/mohammadstyle1/",
  branchCount: 2,
} as const;
export type ServiceId = "groom" | "hair" | "facial" | "massage" | "manicure" | "pedicure";
export type Service = { id: ServiceId; name: string; subtitle: string; icon: string; image?: string; evidence?: string; conceptual?: boolean };
export const services: Service[] = [
  { id: "groom", name: "استایل دامادی", subtitle: "استایل برای روز خاص", icon: "crown", image: "/images/hero-groom.webp", evidence: "مربوط به استایل رسمی و آماده‌سازی داماد" },
  { id: "hair", name: "هیرکات مو", subtitle: "اصلاح و استایل مو", icon: "scissors", image: "/images/barber-working.webp", evidence: "تصویر واقعی آرایشگر در حال کار" },
  { id: "facial", name: "فیشیال صورت", subtitle: "مراقبت از پوست", icon: "sparkle", image: "/images/mohammadstyle-images/mohammadstyle-services-facial-concept.webp", conceptual: true, evidence: "تصویر مفهومی فیشیال مردانه؛ استفاده از براش ماسک روی گونه در فضای تیره و گرم" },
  { id: "massage", name: "ماساژ", subtitle: "آرامش و مراقبت", icon: "leaf", image: "/images/mohammadstyle-images/mohammadstyle-services-massage-concept.webp", conceptual: true, evidence: "تصویر مفهومی ماساژ؛ دست‌های درمانگر روی شانه‌های مردی با پوشش حوله" },
  { id: "manicure", name: "مانیکور", subtitle: "آراستگی دست‌ها", icon: "hand", image: "/images/mohammadstyle-images/mohammadstyle-services-manicure-concept.webp", conceptual: true, evidence: "تصویر مفهومی مانیکور مردانه؛ سوهان‌زدن ناخن طبیعی دست روی حولهٔ تیره" },
  { id: "pedicure", name: "پدیکور", subtitle: "مراقبت از پا", icon: "foot", image: "/images/mohammadstyle-images/mohammadstyle-services-pedicure-concept.webp", conceptual: true, evidence: "تصویر مفهومی پدیکور مردانه؛ مراقبت از کف پا و ناخن‌ها روی حولهٔ روشن" },
];
export type GalleryCategory = "all" | "beforeafter" | "groom" | "behind";
export const gallery = [
  { id: "transformation", title: "تغییر استایل", category: "beforeafter" as const, type: "Before / After", image: "/images/before-after-hair.webp", alt: "مقایسه قبل و بعد از آرایش مو، ارائه‌شده توسط مجموعه" },
  { id: "barber", title: "آرایشگر مجموعه", category: "behind" as const, type: "The Barber", image: "/images/groom-look.webp", alt: "پرتره آرایشگر مجموعه با کت‌وشلوار در فضای باز" },
  { id: "craft", title: "جزئیات یک اصلاح", category: "behind" as const, type: "Behind The Craft", image: "/images/barber-process.webp", alt: "آرایشگر در حال آماده‌سازی موی مشتری" },
  { id: "grooming", title: "قبل و بعد", category: "beforeafter" as const, type: "Before / After", image: "/images/before-after-groom.webp", alt: "تصویر قبل و بعد دیگر از مجموعه" },
  { id: "moment", title: "آماده‌سازی برای مراسم", category: "groom" as const, type: "The Occasion", image: "/images/groom-occasion.webp", alt: "آماده‌سازی مو در محیط فضای باز" },
  { id: "work", title: "از نزدیک", category: "behind" as const, type: "The Process", image: "/images/barber-working.webp", alt: "عکس واقعی از اصلاح مو کنار پنجره سالن" }
];
