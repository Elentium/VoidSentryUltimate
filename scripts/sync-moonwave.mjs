import fs from "fs";
import os from "os";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectDir = path.resolve(__dirname, "..");
const projectName = path.basename(projectDir);
const API_PAGINATION_MARKER = "moonwave-api-pagination";

function getMoonwaveCacheDir() {
	if (process.platform === "darwin") {
		return path.join(os.homedir(), "Library", "Caches", "moonwave", projectName);
	}
	if (process.platform === "win32") {
		return path.join(
			process.env.LOCALAPPDATA || path.join(os.homedir(), "AppData", "Local"),
			"moonwave-nodejs",
			"Cache",
			projectName,
		);
	}
	return path.join(os.homedir(), ".cache", "moonwave", projectName);
}

function copyIfExists(source, destination) {
	if (!fs.existsSync(source)) return false;
	fs.mkdirSync(path.dirname(destination), { recursive: true });
	fs.cpSync(source, destination, { recursive: true, force: true });
	return true;
}

function syncTheme(cacheDir) {
	const source = path.join(projectDir, ".moonwave", "theme");
	const target = path.join(cacheDir, "src", "theme");
	if (!copyIfExists(source, target)) {
		console.warn("Moonwave sync: no .moonwave/theme directory found");
		return;
	}
	console.log("Moonwave sync: applied theme overrides");
}

function syncStatic(cacheDir) {
	const source = path.join(projectDir, ".moonwave", "static");
	const target = path.join(cacheDir, "static");
	if (!copyIfExists(source, target)) return;
	console.log("Moonwave sync: applied static assets");
}

function syncSearchIndex(cacheDir) {
	const buildDir = path.join(projectDir, "build");
	const staticDir = path.join(cacheDir, "static");
	if (!fs.existsSync(buildDir)) {
		console.warn(
			"Moonwave sync: no build/ directory yet — run npm run docs:build once to generate the search index",
		);
		return;
	}

	fs.mkdirSync(staticDir, { recursive: true });
	let copied = 0;
	for (const fileName of fs.readdirSync(buildDir)) {
		if (
			fileName === "search-doc.json" ||
			fileName === "lunr-index.json" ||
			fileName.startsWith("search-doc-") ||
			fileName.startsWith("lunr-index-")
		) {
			fs.copyFileSync(path.join(buildDir, fileName), path.join(staticDir, fileName));
			copied += 1;
		}
	}

	if (copied === 0) {
		console.warn("Moonwave sync: build/ exists but no search index files were found");
		return;
	}
	console.log(`Moonwave sync: copied ${copied} search index file(s) into dev static/`);
}

function findMoonwaveDistFile(fileName) {
	try {
		return fileURLToPath(import.meta.resolve(`moonwave/dist/${fileName}`));
	} catch {
		// Fall through to common npx cache locations for older Node/Moonwave setups.
	}

	const npmCache = process.env.npm_config_cache || path.join(os.homedir(), ".npm");
	const roots = [
		path.join(npmCache, "_npx"),
		path.join(os.homedir(), ".npm", "_npx"),
	];
	for (const root of roots) {
		if (!fs.existsSync(root)) continue;
		for (const entry of fs.readdirSync(root)) {
			const candidate = path.join(
				root,
				entry,
				"node_modules",
				"moonwave",
				"dist",
				fileName,
			);
			if (fs.existsSync(candidate)) return candidate;
		}
	}
	return null;
}

function patchMoonwavePrepareProject() {
	const marker = "moonwave-custom-theme-copy";
	const preparePath = findMoonwaveDistFile("prepareProject.js");
	if (!preparePath) return;

	let source = fs.readFileSync(preparePath, "utf8");
	if (source.includes(marker)) return;

	const insertion =
		`\n    const customThemePath = path.join(projectDir, ".moonwave", "theme");\n` +
		`    if (fs.existsSync(customThemePath)) {\n` +
		`        fs.copySync(customThemePath, path.join(tempDir, "src", "theme"));\n` +
		`    }\n    // ${marker}\n`;
	if (!source.includes("return status;")) {
		console.warn("Moonwave sync: could not patch prepareProject.js");
		return;
	}

	source = source.replace("return status;", `${insertion}    return status;`);
	fs.writeFileSync(preparePath, source);
	console.log(`Moonwave sync: patched prepareProject for theme copy (${preparePath})`);
}

function flattenSidebarSnippet() {
	return `
function flattenApiSidebar(items) {
  const pages = []
  for (const item of items || []) {
    if (item.type === "link" && item.href?.startsWith("/api/")) {
      pages.push({
        permalink: item.href,
        title: String(item.label || "").replace(/\\u200b/g, "").trim(),
      })
    }
    if (item.items) pages.push(...flattenApiSidebar(item.items))
  }
  return pages
}
`;
}

function patchLuaClassApiPagination(cacheDir) {
	const luaClassPath = path.join(
		cacheDir,
		"node_modules",
		"docusaurus-plugin-moonwave",
		"src",
		"components",
		"LuaClass.js",
	);
	if (!fs.existsSync(luaClassPath)) {
		console.warn("Moonwave sync: LuaClass.js not found yet (start moonwave once)");
		return;
	}

	let source = fs.readFileSync(luaClassPath, "utf8");
	const newline = source.includes("\r\n") ? "\r\n" : "\n";

	if (!source.includes('import DocPaginator from "@theme/DocPaginator"')) {
		const layoutImport = 'import Layout from "@theme/Layout"';
		if (!source.includes(layoutImport)) {
			console.warn("Moonwave sync: could not insert DocPaginator import");
			return;
		}
		source = source.replace(
			layoutImport,
			`${layoutImport}${newline}import DocPaginator from "@theme/DocPaginator"`,
		);
	}

	if (!source.includes("function flattenApiSidebar(")) {
		const helperAnchor = ["export const TypeLinksContext", "const TypeLinksContext"].find(
			(anchor) => source.includes(anchor),
		);
		if (!helperAnchor) {
			console.warn("Moonwave sync: could not insert flattenApiSidebar helper");
			return;
		}
		const insertAt = source.indexOf(helperAnchor);
		const helper = flattenSidebarSnippet().replace(/\n/g, newline);
		source = source.slice(0, insertAt) + helper + newline + source.slice(insertAt);
	}

	// A changelog route is not generated when the source directory is not a Git
	// checkout, even with `changelog = true`. Keep previously patched caches
	// buildable by returning the last API page to the guide introduction.
	source = source.replace(
		'if (item.type === "link" && item.href) {',
		'if (item.type === "link" && item.href?.startsWith("/api/")) {',
	);
	source = source.replace(
		': { permalink: "/changelog", title: "Changelog" }',
		': { permalink: "/docs/intro", title: "Guides" }',
	);
	source = source.replace(
		`                    : undefined${newline}                  return (`,
		`                    : { permalink: "/docs/intro", title: "Guides" }${newline}                  return (`,
	);
	source = source.replace(
		': { permalink: "/docs/advanced", title: "Advanced" }',
		': { permalink: "/docs/benchmarks", title: "Benchmarks" }',
	);
	source = source.replace(
		': { permalink: "/docs/best-practices", title: "Best practices" }',
		': { permalink: "/docs/benchmarks", title: "Benchmarks" }',
	);
	source = source.replace("next={next}", "next={next || null}");

	if (!source.includes(API_PAGINATION_MARKER)) {
		const block = [
			`                {/* ${API_PAGINATION_MARKER} */}`,
			`                {(() => {`,
			`                  const apiPages = flattenApiSidebar(sidebarClassNames)`,
			`                  const currentIndex = apiPages.findIndex(`,
			`                    (page) => page.permalink === \`/api/\${luaClass.name}\``,
			`                  )`,
			`                  const previous = currentIndex > 0`,
			`                    ? apiPages[currentIndex - 1]`,
			`                    : { permalink: "/docs/benchmarks", title: "Benchmarks" }`,
			`                  const next = currentIndex >= 0 && currentIndex < apiPages.length - 1`,
			`                    ? apiPages[currentIndex + 1]`,
			`                    : { permalink: "/docs/intro", title: "Guides" }`,
			`                  return (`,
			`                    <DocPaginator`,
			`                      className="docusaurus-mt-lg"`,
			`                      previous={previous}`,
			`                      next={next || null}`,
			`                    />`,
			`                  )`,
			`                })()}`,
			``,
		].join(newline);

		const anchors = [
			["                <details>", "                  <summary>Show raw api</summary>"].join(newline),
			["                <details>", "                  <summary>Show raw API</summary>"].join(newline),
		];
		const anchor = anchors.find((candidate) => source.includes(candidate));
		if (!anchor) {
			console.warn("Moonwave sync: could not insert API pagination block");
			return;
		}
		source = source.replace(anchor, `${block}${anchor}`);
	}

	const previous = fs.readFileSync(luaClassPath, "utf8");
	if (previous === source) return;

	fs.writeFileSync(luaClassPath, source);
	console.log("Moonwave sync: ensured API page prev/next pagination");
}

function runSync({ full = true } = {}) {
	const cacheDir = getMoonwaveCacheDir();
	if (!fs.existsSync(cacheDir)) {
		console.warn(
			`Moonwave sync: cache directory does not exist yet (${cacheDir}). It will be created when moonwave starts.`,
		);
		if (!full) return;
	}

	if (full) {
		patchMoonwavePrepareProject();
		if (fs.existsSync(cacheDir)) {
			syncSearchIndex(cacheDir);
			patchLuaClassApiPagination(cacheDir);
		}
	}

	if (fs.existsSync(cacheDir)) {
		syncTheme(cacheDir);
		syncStatic(cacheDir);
	}
}

let watchTimer;
function scheduleLightSync() {
	clearTimeout(watchTimer);
	watchTimer = setTimeout(() => runSync({ full: false }), 300);
}

function watch() {
	for (const target of [
		path.join(projectDir, ".moonwave", "theme"),
		path.join(projectDir, ".moonwave", "custom.css"),
		path.join(projectDir, ".moonwave", "static"),
	]) {
		if (fs.existsSync(target)) {
			fs.watch(target, { recursive: true }, scheduleLightSync);
		}
	}
	console.log(
		"Moonwave sync: watching theme, CSS, and static/ (light sync only — restart dev after API pagination changes)",
	);
}

const isWatch = process.argv.includes("--watch");
runSync({ full: !isWatch });
if (isWatch) watch();
