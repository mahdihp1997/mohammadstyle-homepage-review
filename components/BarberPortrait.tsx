'use client';
import {useState} from 'react';
export default function BarberPortrait({name,src,alternate}:{name:string;src:string;alternate:string}){
 const[second,setSecond]=useState(false);
 return <div className="barber-portrait"><img src={second?alternate:src} alt={'پرترهٔ '+name} loading="lazy"/><button type="button" aria-pressed={second} aria-label={'نمای دیگر از '+name} onClick={()=>setSecond(x=>!x)}>{second?'قاب اول':'قاب دیگر'} <span aria-hidden="true">↗</span></button></div>;
}
