const issue = {
	issue_number: context.issue.number,
	owner: context.repo.owner,
	repo: context.repo.repo
};

	// Is the title long enough to convey any useful meaning?
if (process.env.ISSUE_TITLE.length < 10)
{
	github.rest.issues.createComment({
		...issue,
		body: "Closing this issue, the title is too short to convey any real meaning, please create another issue with an explanatory title."
	});

	github.rest.issues.update({
		...issue,
		state: "closed",
		state_reason: "not_planned"
	});

	return;
}

// labels
{
	const issueBody = process.env.ISSUE_BODY;
	
	var addLabels = ["triage"];
	
	// Product labels
	{
		const productsStringRegex = /### Product\(s\)\s*([\w, ]*)/;

		var productsString = productsStringRegex.exec(issueBody);
		if (productsString)
		{
			var products = productsString[1].split(/[ ,]+/);              
			for (var i = 0; i < products.length; ++i)
			{
				const product = products[i];
				switch (product)
				{
					case "FxDK": addLabels.push("sdk"); break;
				}
			}
		}
	}
	
	github.rest.issues.addLabels({
		...issue,
		labels: addLabels
	});
}