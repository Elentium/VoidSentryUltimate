const prefix = "algolia-docsearch-suggestion";

const templates = {
	suggestion: `
		<a class="${prefix}" aria-label="Link to the result" href="{{{url}}}">
			<div class="${prefix}--wrapper">
				<div class="${prefix}--content">
					<div class="${prefix}--category">{{{category}}}</div>
					<div class="${prefix}--title">{{{title}}}</div>
					{{#text}}<div class="${prefix}--text">{{{text}}}</div>{{/text}}
				</div>
			</div>
		</a>
	`,
	empty: `
		<div class="${prefix}">
			<div class="${prefix}--wrapper">
				<div class="${prefix}--content ${prefix}--no-results">
					No results found for <b>"{{query}}"</b>
				</div>
			</div>
		</div>
	`,
	footer: '<div class="algolia-docsearch-footer"></div>',
};

export default templates;
