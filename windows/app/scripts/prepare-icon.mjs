import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const here = path.dirname(fileURLToPath(import.meta.url));
const output = path.resolve(here, "../build/icon.png");
const svg = `
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="g" x1="48" y1="32" x2="472" y2="480" gradientUnits="userSpaceOnUse">
      <stop stop-color="#39c5bb"/>
      <stop offset="0.52" stop-color="#2674c7"/>
      <stop offset="1" stop-color="#f4628a"/>
    </linearGradient>
  </defs>
  <rect x="24" y="24" width="464" height="464" rx="92" fill="#071116"/>
  <rect x="42" y="42" width="428" height="428" rx="78" fill="url(#g)"/>
  <path d="M160 180 84 256l76 76M352 180l76 76-76 76M298 128l-84 256" fill="none" stroke="#fff" stroke-width="38" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="397" cy="112" r="34" fill="#fff" opacity=".92"/>
  <path d="m397 91 6 15 15 6-15 6-6 15-6-15-15-6 15-6Z" fill="#f4628a"/>
</svg>`;

await fs.mkdir(path.dirname(output), { recursive: true });
await sharp(Buffer.from(svg)).resize(512, 512).png().toFile(output);
console.log(output);
