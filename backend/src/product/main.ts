import {loadProductConfig,secret} from './config.js';import {createProductApp} from './app.js';import {LocalMediaStorage,S3MediaStorage,type MediaStorage} from '../mvp/storage.js';
const cfg=loadProductConfig();
if(process.env.PRODUCT_STORAGE&&!['local','s3'].includes(process.env.PRODUCT_STORAGE))throw Error('Unknown private storage provider');
const storage:MediaStorage=process.env.PRODUCT_STORAGE==='s3'?new S3MediaStorage({endpoint:process.env.S3_ENDPOINT??'',bucket:process.env.S3_BUCKET??'',region:process.env.S3_REGION??'',accessKey:secret(process.env,'S3_ACCESS_KEY')!,secretKey:secret(process.env,'S3_SECRET_KEY')!}):new LocalMediaStorage(cfg.mediaRoot);
await storage.prepare?.();const app=await createProductApp(cfg,storage);await app.listen(cfg.port,cfg.listenHost);
