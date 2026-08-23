import fs from "node:fs";
import path from "node:path";

const [, , output, ...inputs] = process.argv;
if (!output || inputs.length === 0) {
  throw new Error("Usage: node png-to-ico.mjs output.ico input.png...");
}

const images = inputs.map((path) => {
  const data = fs.readFileSync(path);
  const width = data.readUInt32BE(16);
  const height = data.readUInt32BE(20);
  if (width > 256 || height > 256) {
    throw new Error(`ICO layer is too large: ${path} (${width}x${height})`);
  }
  return { data, width, height };
});

const header = Buffer.alloc(6 + images.length * 16);
header.writeUInt16LE(0, 0);
header.writeUInt16LE(1, 2);
header.writeUInt16LE(images.length, 4);

let offset = header.length;
images.forEach((image, index) => {
  const entry = 6 + index * 16;
  header[entry] = image.width === 256 ? 0 : image.width;
  header[entry + 1] = image.height === 256 ? 0 : image.height;
  header[entry + 2] = 0;
  header[entry + 3] = 0;
  header.writeUInt16LE(1, entry + 4);
  header.writeUInt16LE(32, entry + 6);
  header.writeUInt32LE(image.data.length, entry + 8);
  header.writeUInt32LE(offset, entry + 12);
  offset += image.data.length;
});

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, Buffer.concat([header, ...images.map((image) => image.data)]));
