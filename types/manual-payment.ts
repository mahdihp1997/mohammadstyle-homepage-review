export interface BankCard {
 id:string;bankName:string;cardNumber:string;cardholder:string;lastFour:string;scopeKind:'BUSINESS'|'BRANCHES';branchIds:string[];priority:number;active:boolean;archivedAt:string|null;version:string;
}
export interface ManualReceipt {
 id:string;submission:number;submittedAt:string;imageAvailable:boolean;imageUrl:string;senderReference?:string;status:string;
 review?:{decision:string;reason:string;reviewerId:string;at:string}|null;
}
export interface ManualTransfer {
 version:string;maxSubmissions:number;destination:BankCard;cardCurrentlyActive:boolean;receipts:ManualReceipt[];
 reconciliation?:{source:'MANUAL_BANK_RECONCILED';receivedAmountRial:string;receivedAt:string;outcome:string;reviewerId:string;bankReference:string}|null;
}
export interface PaymentMethods {
 onlineEnabled:boolean;manualEnabled:boolean;mode:string;cards:BankCard[];expiresAt:string;existingIntentId?:string;
}
export const paymentStates:Record<string,string>={REQUESTED:'در حال ساخت درخواست پرداخت',REDIRECT_READY:'آمادهٔ انتقال به درگاه',VERIFYING:'در انتظار تأیید مستقل درگاه',VERIFIED:'پرداخت تأیید شده توسط درگاه',DECLINED:'پرداخت ناموفق یا لغوشده',UNKNOWN:'نتیجهٔ نامشخص؛ در حال بررسی',CLOSED:'مهلت پرداخت پایان یافته',REVIEW:'در انتظار بررسی بازپرداخت',AWAITING_TRANSFER:'در انتظار واریز و ارسال رسید',UNDER_REVIEW:'رسید در انتظار بررسی',REJECTED:'رسید نیاز به اصلاح دارد',REVIEW_REQUIRED:'نیازمند بررسی مالی و وضعیت نوبت'};
