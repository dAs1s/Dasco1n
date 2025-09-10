import axios from 'axios';
import { ENV } from './env.js';

export const api = axios.create({
  baseURL: ENV.API_BASE_URL,
  timeout: 15_000,
});

api.interceptors.request.use((config) => {
  config.headers = config.headers ?? {};
  if (ENV.API_AUTH_TOKEN) {
    config.headers[ENV.API_AUTH_HEADER] = ENV.API_AUTH_TOKEN;
  }
  return config;
});
