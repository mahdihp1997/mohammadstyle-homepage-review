import {rialLabel} from '@/lib/booking/server-adapter';
import {fulfillmentStates,orderStates,type ShopOrder} from '@/types/shop';

export const orderDate=(value:string)=>new Intl.DateTimeFormat('fa-IR',{timeZone:'Asia/Tehran',dateStyle:'medium',timeStyle:'short'}).format(new Date(value));
const events:Record<string,string>={created:'سفارش ثبت شد',paid:'واریز تأیید شد',expired:'مهلت پرداخت پایان یافت',cancel:'سفارش پرداخت‌نشده لغو شد','request-cancellation':'درخواست لغو دریافت شد','accept-cancellation':'لغو پذیرفته شد؛ بررسی بازپرداخت','decline-cancellation':'درخواست لغو پذیرفته نشد',fulfill:'وضعیت آماده‌سازی به‌روز شد'};
export default function OrderDetails({order:o}:{order:ShopOrder}){
 return <div className="shop-order-details">
  <div className="product-actions"><span className="product-badge">{orderStates[o.status]??o.status}</span>{o.status==='PAID'&&<span className="product-badge">{fulfillmentStates[o.fulfillmentState]??o.fulfillmentState}</span>}</div>
  <p>{orderDate(o.createdAt)} · {o.branchName}</p>
  <ul className="shop-order-items">{o.quote.items.map(i=><li key={i.productId}><span>{i.name} <small>× {i.quantity.toLocaleString('fa-IR')}</small></span><strong>{rialLabel(i.lineRial)}</strong></li>)}</ul>
  <dl className="shop-cart-total"><dt>جمع محصولات</dt><dd>{rialLabel(o.quote.subtotalRial)}</dd><dt>{o.shippingMethod==='PICKUP'?'تحویل حضوری':'ارسال'}</dt><dd>{rialLabel(o.quote.shippingRial)}</dd><dt>مبلغ نهایی</dt><dd><strong>{rialLabel(o.totalRial)}</strong></dd></dl>
  <p>تحویل‌گیرنده: {o.shippingDetails.recipientName}{o.shippingDetails.mobile&&<> · <bdi>{o.shippingDetails.mobile}</bdi></>}</p>
  {o.shippingMethod==='DELIVERY'&&<p>{o.shippingDetails.province}، {o.shippingDetails.city}، {o.shippingDetails.address}<br/>کد پستی: <bdi>{o.shippingDetails.postalCode}</bdi></p>}
  {o.trackingReference&&<p>شناسهٔ پیگیری ارسال: <bdi>{o.trackingReference}</bdi></p>}
  {o.cancellationState&&<p role="status">{o.cancellationState==='REQUESTED'?'درخواست لغو در حال بررسی است؛ آماده‌سازی متوقف شده است.':o.cancellationState==='ACCEPTED'?'درخواست لغو پذیرفته شده؛ وضعیت بازپرداخت را پیگیری کنید.':'درخواست لغو پذیرفته نشده است؛ دلیل در سابقه ثبت شده است.'}</p>}
  <div className="shop-public-terms">{[['شرایط پذیرفته‌شدهٔ خرید',o.quote.termsText],['شرایط لغو و مرجوعی پذیرفته‌شده',o.quote.returnsText],['شرایط تحویل پذیرفته‌شده',o.quote.shippingText]].map(([label,body])=><details key={label}><summary>{label}</summary><p>{body}</p></details>)}<details><summary>سابقهٔ سفارش</summary><ol>{o.history.map((h,i)=><li key={i}><strong>{events[h.kind]??'رویداد سفارش'}</strong> · <time dateTime={h.at}>{orderDate(h.at)}</time>{typeof h.details.reason==='string'&&<p>{h.details.reason}</p>}{typeof h.details.fulfillmentState==='string'&&<p>{fulfillmentStates[h.details.fulfillmentState]??h.details.fulfillmentState}</p>}</li>)}</ol></details></div>
 </div>;
}
