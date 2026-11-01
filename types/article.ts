export interface ArticleDocument{title:string;summary:string;body:string;authorName:string;category:string;coverId:string|null}
export interface Article extends ArticleDocument{id:string;slug:string;publishedAt:string}
export interface ArticleDraft{id:string;slug:string;version:string;draft:ArticleDocument;published:boolean;publishedVersion:string|null;archivedAt:string|null;updatedAt:string}
