import * as fs from "node:fs";
import * as path from "node:path";
import dotenv from "dotenv";

// Always load ONLY the root .env
const ROOT_ENV = "C:\\Dasco1n\\.env";
if (fs.existsSync(ROOT_ENV)) {
  dotenv.config({ path: ROOT_ENV });
  console.log(`[env] Loaded ${ROOT_ENV}`);
} else {
  console.warn(`[env] Root .env not found at ${ROOT_ENV}`);
}