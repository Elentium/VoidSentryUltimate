import lunr from "@generated/lunr.client";

lunr.tokenizer.separator = /[\s\-/]+/;

class LunrSearchAdapter {
	constructor(searchDocs, searchIndex, baseUrl = "/", maxHits = 5) {
		this.searchDocs = searchDocs;
		this.lunrIndex = lunr.Index.load(searchIndex);
		this.baseUrl = baseUrl;
		this.maxHits = maxHits;
	}

	getLunrResult(input) {
		return this.lunrIndex.query((query) => {
			const tokens = lunr.tokenizer(input);
			query.term(tokens, { boost: 10 });
			query.term(tokens, { wildcard: lunr.Query.wildcard.TRAILING });
		});
	}

	getHit(doc, title, content) {
		return {
			hierarchy: {
				lvl0: doc.pageTitle || doc.title,
				lvl1: doc.type === 0 ? null : doc.title,
			},
			url: doc.url,
			version: doc.version,
			content,
			title,
		};
	}

	highlight(value, position, length) {
		const start = position[0];
		const end = start + length;
		return `${value.slice(0, start)}<span class="algolia-docsearch-suggestion--highlight">${value.slice(start, end)}</span>${value.slice(end)}`;
	}

	search(input) {
		const hits = [];
		for (const result of this.getLunrResult(input).slice(0, this.maxHits)) {
			const doc = this.searchDocs[result.ref];
			const metadata = result.matchData.metadata;
			const match = Object.values(metadata)[0] || {};
			if (match.title) {
				hits.push(
					this.getHit(
						doc,
						this.highlight(doc.title, match.title.position[0], input.length),
						null,
					),
				);
			} else if (match.content) {
				const position = match.content.position[0];
				const start = position[0];
				const end = start + position[1];
				const left = Math.max(0, start - 60);
				const right = Math.min(doc.content.length, end + 100);
				const preview =
					(left ? "… " : "") +
					this.highlight(doc.content.slice(left, right), [start - left], position[1]) +
					(right < doc.content.length ? " …" : "");
				hits.push(this.getHit(doc, doc.title, preview));
			} else if (match.keywords) {
				hits.push(this.getHit(doc, doc.title, null));
			}
		}
		return Promise.resolve(hits);
	}
}

export default LunrSearchAdapter;
