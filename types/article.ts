export interface ArticleDocument{title:string;summary:string;body:string;authorName:string;category:string;coverId:string|null}
export interface Article extends ArticleDocument{id:string;slug:string;publishedAt:string}
/** List responses intentionally omit the article body; detail responses include it. */
export type ArticleSummary=Omit<Article,'body'>;
export interface ArticleDraft{id:string;slug:string;version:string;draft:ArticleDocument;published:boolean;publishedVersion:string|null;archivedAt:string|null;updatedAt:string}
