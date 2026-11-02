import {test,expect} from '@playwright/test';
import {createElement} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import JournalGrid from '../components/JournalGrid';
import type {ArticleSummary} from '../types/article';

test('Journal renders the actual list contract, which intentionally has no article body',()=>{
  const article:ArticleSummary={id:'summary-only',slug:'summary-without-body',title:'گفت‌وگو پیش از هیرکات',summary:'خلاصهٔ مقاله برای انتخاب مطلب',authorName:'تحریریه',category:'استایل',coverId:null,publishedAt:'2026-11-02T00:00:00.000Z'};
  const html=renderToStaticMarkup(createElement(JournalGrid,{articles:[article,{...article,id:'second',slug:'second-story',title:'پرداخت نهایی مو'}]}));
  expect(html).toContain(article.title);
  expect(html).toContain('پرداخت نهایی مو');
  expect(html).toContain('/blog/summary-without-body');
  expect(html).toContain('موضوعات مجله');
});
