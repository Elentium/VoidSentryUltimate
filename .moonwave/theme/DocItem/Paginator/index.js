import React from "react";
import clsx from "clsx";
import { ThemeClassNames } from "@docusaurus/theme-common";
import { useDoc } from "@docusaurus/plugin-content-docs/client";
import DocPaginator from "@theme/DocPaginator";

const API_FIRST = {
	permalink: "/api/VoidSentryUltimate",
	title: "VoidSentryUltimate",
};

export default function DocItemPaginator() {
	const { metadata } = useDoc();
	let { previous, next } = metadata;

	if (
		!next &&
		(metadata.id === "benchmarks" || metadata.permalink?.endsWith("/benchmarks"))
	) {
		next = API_FIRST;
	}

	return (
		<DocPaginator
			className={clsx(ThemeClassNames.docs.docPaginator, "docusaurus-mt-lg")}
			previous={previous}
			next={next}
		/>
	);
}
