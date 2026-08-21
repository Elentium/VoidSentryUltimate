import Mark from "mark.js";
import { useEffect, useState } from "react";
import { useLocation, useHistory } from "@docusaurus/router";
import useDocusaurusContext from "@docusaurus/useDocusaurusContext";

export function HighlightSearchResults() {
	const location = useLocation();
	const history = useHistory();
	const {
		siteConfig: { baseUrl },
	} = useDocusaurusContext();
	const [word, setWord] = useState("");

	useEffect(() => {
		const wordToHighlight = location.state?.highlightState?.wordToHighlight;
		if (!wordToHighlight) return;
		setWord(wordToHighlight);
		const { highlightState, ...state } = location.state;
		history.replace({ ...location, state });
	}, [history, location]);

	useEffect(() => {
		if (!word) return;
		const root =
			document.getElementsByTagName("article")[0] ??
			document.getElementsByTagName("main")[0];
		if (!root) return;
		const mark = new Mark(root);
		const options = { ignoreJoiners: true };
		mark.mark(word, options);
		return () => mark.unmark(options);
	}, [baseUrl, word]);

	return null;
}
