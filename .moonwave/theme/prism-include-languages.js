import siteConfig from "@generated/docusaurus.config";

export default function prismIncludeLanguages(PrismObject) {
	const {
		themeConfig: { prism },
	} = siteConfig;
	const { additionalLanguages = [] } = prism;
	const PrismBefore = globalThis.Prism;
	globalThis.Prism = PrismObject;

	additionalLanguages.forEach((lang) => {
		if (lang === "php") {
			require("prismjs/components/prism-markup-templating.js");
		}
		if (lang !== "luau") require(`prismjs/components/prism-${lang}`);
	});

	if (!PrismObject.languages.lua) require("prismjs/components/prism-lua");
	PrismObject.languages.luau = PrismObject.languages.lua;

	delete globalThis.Prism;
	if (typeof PrismBefore !== "undefined") globalThis.Prism = PrismObject;
}
