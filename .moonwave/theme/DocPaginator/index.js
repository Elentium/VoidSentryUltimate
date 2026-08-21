import React from "react";
import clsx from "clsx";
import Translate, { translate } from "@docusaurus/Translate";
import PaginatorNavLink from "@theme/PaginatorNavLink";

const GUIDES = {
	permalink: "/docs/intro",
	title: "Guides",
};

export default function DocPaginator({ className, previous, next }) {
	// Moonwave's API sidebar may retain a changelog entry while developing from
	// a source export that has no CHANGELOG.md route.
	const safeNext = next?.permalink === "/changelog" ? GUIDES : next;

	return (
		<nav
			className={clsx(className, "pagination-nav")}
			aria-label={translate({
				id: "theme.docs.paginator.navAriaLabel",
				message: "Docs pages",
				description: "The ARIA label for the docs pagination",
			})}
		>
			{previous && (
				<PaginatorNavLink
					{...previous}
					subLabel={
						<Translate
							id="theme.docs.paginator.previous"
							description="The label used to navigate to the previous doc"
						>
							Previous
						</Translate>
					}
				/>
			)}
			{safeNext && (
				<PaginatorNavLink
					{...safeNext}
					subLabel={
						<Translate
							id="theme.docs.paginator.next"
							description="The label used to navigate to the next doc"
						>
							Next
						</Translate>
					}
					isNext
				/>
			)}
		</nav>
	);
}
