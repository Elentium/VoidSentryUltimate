import React, { useCallback, useEffect, useRef, useState } from "react";
import clsx from "clsx";
import { useHistory } from "@docusaurus/router";
import useDocusaurusContext from "@docusaurus/useDocusaurusContext";
import { usePluginData } from "@docusaurus/useGlobalData";
import useIsBrowser from "@docusaurus/useIsBrowser";
import { HighlightSearchResults } from "./HighlightSearchResults";
import "./styles.css";

async function fetchAsset(assetUrl, candidates) {
	for (const fileName of [...new Set(candidates.filter(Boolean))]) {
		try {
			const response = await fetch(`${assetUrl}${fileName}`);
			if (response.ok) return await response.json();
		} catch (error) {
			console.debug(`Moonwave search: ${fileName} unavailable`, error);
		}
	}
	return null;
}

export default function SearchBar(props) {
	const initialized = useRef(false);
	const searchBarRef = useRef(null);
	const [indexReady, setIndexReady] = useState(false);
	const [indexUnavailable, setIndexUnavailable] = useState(false);
	const history = useHistory();
	const isBrowser = useIsBrowser();
	const { siteConfig = {} } = useDocusaurusContext();
	const pluginData = usePluginData("docusaurus-lunr-search");
	const pluginConfig = (siteConfig.plugins || []).find(
		(plugin) =>
			Array.isArray(plugin) &&
			typeof plugin[0] === "string" &&
			plugin[0].includes("docusaurus-lunr-search"),
	);
	const baseUrl = siteConfig.baseUrl || "/";
	const assetUrl = pluginConfig?.[1]?.assetUrl || baseUrl;

	const loadSearch = useCallback(() => {
		if (initialized.current) return;
		initialized.current = true;
		Promise.all([
			fetchAsset(assetUrl, [
				pluginData?.fileNames?.searchDoc,
				"search-doc.json",
			]),
			fetchAsset(assetUrl, [
				pluginData?.fileNames?.lunrIndex,
				"lunr-index.json",
			]),
			import("./DocSearch"),
			import("./algolia.css"),
		])
			.then(([searchDocFile, searchIndex, { default: DocSearch }]) => {
				const { searchDocs, options = {} } = searchDocFile || {};
				if (!searchDocs?.length || !searchIndex) {
					setIndexUnavailable(true);
					return;
				}
				new DocSearch({
					searchDocs,
					searchIndex,
					baseUrl,
					inputSelector: "#search_input_react",
					maxHits: options.maxHits,
					handleSelected: (input, event, suggestion) => {
						input.setVal("");
						event.target.blur();
						history.push(suggestion.url || "/", {
							highlightState: {
								wordToHighlight: suggestion.text || suggestion.title || "",
							},
						});
					},
				});
				setIndexReady(true);
			})
			.catch((error) => {
				console.warn("Moonwave search: failed to initialize", error);
				setIndexUnavailable(true);
			});
	}, [assetUrl, baseUrl, history, pluginData]);

	useEffect(() => {
		if (isBrowser) loadSearch();
	}, [isBrowser, loadSearch]);

	const toggleSearch = useCallback(
		(event) => {
			if (!searchBarRef.current?.contains(event.target)) searchBarRef.current?.focus();
			props.handleSearchBarToggle?.(!props.isSearchBarExpanded);
		},
		[props],
	);

	const shortcut =
		isBrowser && window.navigator.platform.startsWith("Mac") ? "⌘+K" : "Ctrl+K";
	const placeholder = indexReady
		? `Search ${shortcut}`
		: indexUnavailable
			? "Search unavailable (run npm run docs:build)"
			: "Loading...";

	return (
		<div className="navbar__search">
			<span
				aria-label="Expand search"
				role="button"
				className={clsx("search-icon", {
					"search-icon-hidden": props.isSearchBarExpanded,
				})}
				onClick={toggleSearch}
				onKeyDown={toggleSearch}
				tabIndex={0}
			/>
			<input
				id="search_input_react"
				type="search"
				placeholder={placeholder}
				aria-label="Search"
				className={clsx(
					"navbar__search-input",
					props.isSearchBarExpanded ? "search-bar-expanded" : "search-bar",
				)}
				onFocus={toggleSearch}
				onBlur={toggleSearch}
				ref={searchBarRef}
				disabled={!indexReady}
			/>
			<HighlightSearchResults />
		</div>
	);
}
