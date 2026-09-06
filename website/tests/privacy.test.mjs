import assert from "node:assert/strict";
import test from "node:test";
import { readdir, readFile } from "node:fs/promises";
import { createRequire, Module } from "node:module";
import { fileURLToPath } from "node:url";
import { build } from "esbuild";
import { examples } from "../src/examples.js";

const require = createRequire(import.meta.url);
const React = require("react");
const { renderToStaticMarkup } = require("react-dom/server");
const output = await build({ entryPoints: [fileURLToPath(new URL("../src/App.jsx", import.meta.url))], bundle: true, platform: "node", format: "cjs", jsx: "automatic", mainFields: ["module", "main"], external: ["react", "react/jsx-runtime"], write: false });
const filename = fileURLToPath(new URL("../render-test.cjs", import.meta.url));
const compiled = new Module(filename);
compiled.filename = filename;
compiled.paths = require.resolve.paths("react");
compiled._compile(output.outputFiles[0].text, compiled.filename);
const { App, Demo } = compiled.exports;

test("all three examples render fictional content and a clear disclosure", () => {
  assert.equal(Object.keys(examples).length, 3);
  for (const [key, example] of Object.entries(examples)) {
    const html = renderToStaticMarkup(React.createElement(Demo, { initialSelected: key }));
    assert.ok(html.includes(example.title));
    assert.ok(html.includes("실제 개인 설정이 아닙니다"));
    assert.equal((html.match(/aria-pressed="true"/g) || []).length, 1);
    assert.ok(html.includes(example.result));
  }
});

test("site renders installation, privacy and download information without storage", () => {
  const prior = Object.getOwnPropertyDescriptor(globalThis, "localStorage");
  Object.defineProperty(globalThis, "localStorage", { configurable: true, get() { throw new Error("Storage disabled"); } });
  try {
    const html = renderToStaticMarkup(React.createElement(App));
    for (const text of ["macOS 14 이상", "가상 예시", "손쉬운 사용", "입력 모니터링", "releases/latest"]) assert.ok(html.includes(text));
    assert.ok(!html.includes("<form"));
  } finally {
    if (prior) Object.defineProperty(globalThis, "localStorage", prior);
    else delete globalThis.localStorage;
  }
});

test("only the approved brand icon is copied from public assets", async () => {
  const files = await readdir(new URL("../public/assets/", import.meta.url));
  assert.deepEqual(files, ["wikey-icon.png"]);
  const publicFiles = await readdir(new URL("../public/", import.meta.url));
  assert.deepEqual(publicFiles, ["assets"]);
});

test("built website contains no old capture, local user path, or private configuration", async () => {
  const root = new URL("../dist/client/", import.meta.url);
  const paths = await readdir(root, { recursive: true, withFileTypes: true });
  for (const entry of paths.filter((entry) => entry.isFile())) {
    assert.ok(!/wikey-workflows|design-reference|home\.png|config\.json|\.map$/.test(entry.name));
    if (!/\.(js|css|html)$/.test(entry.name)) continue;
    const body = await readFile(`${entry.parentPath}/${entry.name}`, "utf8");
    assert.ok(!/wikey-workflows\.png|design-reference\.png|\/Users\/|Library\/Application Support/.test(body));
  }
});
