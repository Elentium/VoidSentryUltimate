import Hogan from "hogan.js";
import autocomplete from "autocomplete.js";
import $ from "autocomplete.js/zepto";
import LunrSearchAdapter from "./lunar-search";
import templates from "./templates";
import utils from "./utils";

class DocSearch {
	constructor({
		searchDocs,
		searchIndex,
		inputSelector,
		baseUrl = "/",
		handleSelected,
		maxHits = 5,
	}) {
		this.input = $(inputSelector).filter("input");
		this.client = new LunrSearchAdapter(searchDocs, searchIndex, baseUrl, maxHits);
		this.handleSelected = handleSelected || this.handleSelected;
		this.autocomplete = autocomplete(
			this.input,
			{
				hint: false,
				autoselect: true,
				cssClasses: { prefix: "ds" },
				ariaLabel: this.input.attr("aria-label") || "Search input",
			},
			[
				{
					source: (query, callback) =>
						this.client.search(query).then((hits) => callback(DocSearch.formatHits(hits))),
					templates: {
						suggestion: (suggestion) =>
							Hogan.compile(templates.suggestion).render(suggestion),
						empty: (args) => Hogan.compile(templates.empty).render(args),
						footer: templates.footer,
					},
				},
			],
		);
		this.autocomplete.on(
			"autocomplete:selected",
			this.handleSelected.bind(null, this.autocomplete.autocomplete),
		);
		document.addEventListener("keydown", (event) => {
			if ((event.ctrlKey || event.metaKey) && event.key === "k") {
				this.input.focus();
				event.preventDefault();
			}
		});
	}

	static formatHits(receivedHits) {
		return utils.deepClone(receivedHits).map((hit) => ({
			category: hit.hierarchy.lvl0,
			subcategory: hit.hierarchy.lvl1,
			title: hit.title || hit.hierarchy.lvl1 || hit.hierarchy.lvl0,
			text: hit.content,
			url: hit.url,
			version: hit.version,
		}));
	}

	handleSelected(input, _event, suggestion, _datasetNumber, context = {}) {
		if (context.selectionMethod === "click") return;
		input.setVal("");
		window.location.assign(suggestion.url);
	}
}

export default DocSearch;
