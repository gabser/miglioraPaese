import { promisify } from 'node:util';
import { createHash,scrypt } from 'node:crypto';
import { httpError } from '../errors.js';
export const iso=value=>new Date(value).toISOString();
export const digest=code=>createHash('sha256').update(code).digest('hex');
const deriveCodeHash=promisify(scrypt);
export const otpHash=async(code,id)=>(await deriveCodeHash(code,id,32)).toString('hex');
export function requireValue(value,code,message,status=400){if(!value)throw httpError(status,code,message);}
export function exact(body,allowed){requireValue(body&&typeof body==='object'&&!Array.isArray(body)&&Object.keys(body).every(k=>allowed.includes(k)),'invalid_field','Unsupported account command field.');}
export function rateError(seconds){return Object.assign(httpError(429,'auth_rate_limited','Wait before requesting another code.'),{retryAfterSeconds:Math.max(1,seconds)});}
