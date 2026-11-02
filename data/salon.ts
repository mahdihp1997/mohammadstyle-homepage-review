import facts from './business-facts.json';
import type{ServiceId} from './site';

const confirmed=facts.verified_or_user_provided.owner_update_2026_11_01;
export const team=confirmed.team.map(person=>({...person,phoneHref:person.phone?'tel:+98'+person.phone.slice(1):null}));
export const tomanLabel=(amount:number)=>new Intl.NumberFormat('fa-IR').format(amount)+' تومان';
export function listedServicePrice(id:ServiceId){
 if(id==='groom')return 'مشاورهٔ پکیج دامادی';
 if(id==='hair')return 'از '+tomanLabel(Math.min(...team.map(x=>x.haircut_price_toman)));
 return tomanLabel(confirmed.service_prices_toman[id]);
}
export const serviceMenu=[
 {id:'facial',label:'فیشیال صورت',price:confirmed.service_prices_toman.facial},
 {id:'massage',label:'ماساژ ریلکسی · یک ساعت',price:confirmed.service_prices_toman.massage},
 {id:'manicure',label:'مانیکور',price:confirmed.service_prices_toman.manicure},
 {id:'pedicure',label:'پدیکور',price:confirmed.service_prices_toman.pedicure},
] as const;
export const privateStaffPhotos:Record<string,{src:string;alternate:string;alt:string}>={
 mohammad:{src:'/images/owner-media/barber-mohammad-formal.webp',alternate:'/images/owner-media/barber-mohammad-salon.webp',alt:'محمد در آینهٔ سالن'},
 amir:{src:'/images/owner-media/barber-amir-formal.webp',alternate:'/images/owner-media/barber-amir-portrait.webp',alt:'پرترهٔ امیر در سالن'},
};
// Owner films and posters are omitted from the public review.
export const privateFilms: readonly {id:string;title:string;alt:string;src:string;poster:string}[]=[];
