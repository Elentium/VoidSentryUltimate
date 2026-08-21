const utils = {
	compact(values) {
		return values.filter(Boolean);
	},

	deepClone(value) {
		return JSON.parse(JSON.stringify(value));
	},

	getHighlightedValue(object, property) {
		return object._highlightResult?.[property]?.value ?? object[property];
	},

	getSnippetedValue(object, property) {
		return object._snippetResult?.[property]?.value ?? object[property];
	},
};

export default utils;
