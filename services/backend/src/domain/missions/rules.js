import { inflateSync,deflateSync } from 'node:zlib';
import { createHash } from 'node:crypto';
import { httpError } from '../errors.js';
export const fail=(code,message,status=400)=>{throw httpError(status,code,message);};
export function exact(body,allowed){if(!body||typeof body!=='object'||Array.isArray(body)||Object.keys(body).some(k=>!allowed.includes(k)))fail('invalid_field','Unsupported mission command.');}
export function key(value){if(typeof value!=='string'||!/^[A-Za-z0-9_-]{8,128}$/.test(value))fail('invalid_field','Invalid idempotency key.');return value;}
export function revision(value){if(!Number.isInteger(value)||value<1)fail('invalid_field','Invalid expectedRevision.');return value;}
export const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
export function uuid(value){if(typeof value!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(value))fail('invalid_field','Invalid resource identifier.');return value;}
const signature=Buffer.from('89504e470d0a1a0a','hex');
function crc(bytes){let c=0xffffffff;for(const b of bytes){c^=b;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0);}return (c^0xffffffff)>>>0;}
export function sanitizePng(input){
 if(input.length>2097152)fail('proof_too_large','Proof exceeds 2 MiB.');
 if(!input.subarray(0,8).equals(signature))fail('proof_invalid','A decoded PNG is required.');
 let offset=8,width,height,channels,header,ended=false;const chunks=[],compressed=[];
 while(offset<input.length){
  if(offset+12>input.length)fail('proof_invalid','Truncated PNG.');
  const length=input.readUInt32BE(offset),end=offset+12+length;
  if(length>2097152||end>input.length)fail('proof_invalid','Invalid PNG chunk.');
  const type=input.toString('latin1',offset+4,offset+8),data=input.subarray(offset+8,offset+8+length);
  if(!/^[A-Za-z]{4}$/.test(type)||crc(input.subarray(offset+4,end-4))!==input.readUInt32BE(end-4))fail('proof_invalid','Invalid PNG checksum.');
  if(offset===8&&type!=='IHDR')fail('proof_invalid','PNG header missing.');
  if(type==='IHDR'){
   header=data;if(width||length!==13)fail('proof_invalid','Invalid PNG header.');width=data.readUInt32BE(0);height=data.readUInt32BE(4);channels=data[9]===6?4:data[9]===2?3:0;
   if(width<1||height<1||width>4096||height>4096||width*height>4000000||data[8]!==8||!channels||data[10]||data[11]||data[12])fail('proof_invalid','Unsupported PNG dimensions or encoding.');
  }else if(type==='IDAT'){if(ended)fail('proof_invalid','Invalid PNG order.');compressed.push(data);}
  else if(type==='IEND'){if(length||!compressed.length)fail('proof_invalid','Invalid PNG end.');ended=true;if(end!==input.length)fail('proof_invalid','Unexpected PNG trailing data.');}
  else if(type[0]===type[0].toUpperCase())fail('proof_invalid','Unsupported critical PNG chunk.');
  // Ancillary chunks, including EXIF/text/location/profile, never enter storage.
  if(['IHDR','IDAT','IEND'].includes(type))chunks.push(input.subarray(offset,end));
  offset=end;
 }
 if(!ended)fail('proof_invalid','PNG end missing.');
 const stride=width*channels+1,expected=stride*height;let decoded;
 try{decoded=inflateSync(Buffer.concat(compressed),{maxOutputLength:expected});}catch{fail('proof_invalid','Invalid or excessive PNG pixel stream.');}
 if(decoded.length!==expected)fail('proof_invalid','Invalid PNG pixel size.');
 for(let row=0;row<height;row++)if(decoded[row*stride]>4)fail('proof_invalid','Invalid PNG scanline filter.');
 const encode=(type,data)=>{const t=Buffer.from(type),size=Buffer.alloc(4),checksum=Buffer.alloc(4);size.writeUInt32BE(data.length);checksum.writeUInt32BE(crc(Buffer.concat([t,data])));return Buffer.concat([size,t,data,checksum]);};
 const bytes=Buffer.concat([signature,encode('IHDR',header),encode('IDAT',deflateSync(decoded)),encode('IEND',Buffer.alloc(0))]);if(bytes.length>2097152)fail('proof_too_large','Sanitized proof exceeds 2 MiB.');return {bytes,width,height,sha256:hash(bytes)};
}
