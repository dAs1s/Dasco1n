import winston from 'winston';
import { ENV } from './env.js';
export const logger = winston.createLogger({
  level: ENV.LOG_LEVEL,
  transports: [ new winston.transports.Console({ format: winston.format.simple() }) ]
});
