package webhooks

test_github_push_master_event {
  ts = resources with input as github_push("master")
  ts[_].spec.taskRef.name = "ci-stage1"
}

test_gitlab_push_master_event {
  ts = resources with input as gitlab_push("master")
  ts[_].spec.taskRef.name = "ci-stage1"
}

test_github_push_non_master_event {
  ts = resources with input as github_push("foo")
	count(ts) == 0
}

test_gitlab_push_non_master_event {
  ts = resources with input as gitlab_push("foo")
	count(ts) == 0
}

test_github_pull_request_opened_event {
	ts = resources with input as github_pull_request("opened")
	ts[_].spec.taskRef.name = "ci-stage1"
}

test_gitlab_merge_request_opened_event {
	ts = resources with input as gitlab_merge_request("opened")
	ts[_].spec.taskRef.name = "ci-stage1"
}

test_github_pull_request_synchronized_event {
	ts = resources with input as github_pull_request("synchronized")
	ts[_].spec.taskRef.name = "ci-stage1"
}

test_gitlab_merge_request_updated_event {
	ts = resources with input as gitlab_merge_request("updated")
	ts[_].spec.taskRef.name = "ci-stage1"
}

test_github_pull_request_closed_event {
	ts = resources with input as github_pull_request("closed")
	substring(ts[_].metadata.generateName, 0, 9) = "delete-ns"
}

test_gitlab_merge_request_closed_event {
	ts = resources with input as gitlab_merge_request("closed")
	substring(ts[_].metadata.generateName, 0, 9) = "delete-ns"
}

test_github_pull_request_non_managed_event {
	ts = resources with input as github_pull_request("review_request_removed")
	count(ts) == 0
}

test_broken_event {
	not event with input as {
		"payload": {},
		"headers": {
			"X-X-X": "foo"
		}
	}
}
