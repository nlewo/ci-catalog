package webhooks

sanitize_branch(branch) = b {
  b := replace(lower(branch), "/", "-")
}

deleteNSTask := {
  "apiVersion": "tekton.dev/v1alpha1",
  "kind": "TaskRun",
  "metadata": {
    "generateName": sprintf("delete-ns-%s", [event.namespace]),
    "namespace": "tekton-pipelines"
  },
  "spec": {
    "serviceAccountName": "tekton-ci-admin",
    "taskSpec": {
      "steps": [
        {
          "name": "delete-namespace",
          "image": "nixery.dev/kubectl",
          "command": ["kubectl"],
          "args": ["delete", "namespace", event.namespace],
        }
      ],
    },
  }
}

stage1Task := {
	"apiVersion": "tekton.dev/v1alpha1",
	"kind": "TaskRun",
	"metadata": {
		"generateName": sprintf("setup-%s-", [event.namespace]),
		"namespace": "tekton-pipelines",
		"labels": {
			"stargate/task": "stage1",
      "tekton.dev/project": event.repository.name,
      "tekton.dev/branch": event.repository.branch,
		},
	},
	"spec": {
		"serviceAccountName": "tekton-ci-admin",
		"taskRef": {
			"name": "ci-stage1"
		},
		"inputs": {
			"params": [
				{"name": "event", "value": json.marshal(event)},
				{"name": "eventType", "value": event.eventType},
				{"name": "eventAction", "value": event.eventAction},
				{"name": "repoName", "value": event.repository.name},
				{"name": "repoBranch", "value": event.repository.branch},
				{"name": "namespace", "value": event.namespace},
			]
		}
	}
}

event = e {
  input.headers["X-Github-Event"][_] = "pull_request"
	repo = lower(input.payload.repository.name)
	branch = sanitize_branch(input.payload.pull_request.head.ref)
	namespace = sprintf("pipeline-%s-%s", [repo, branch])
	e := {
		"eventType": "pull_request",
    "eventAction": input.payload.action,
    "namespace": namespace,
		"repository": {
			"name": repo,
			"url": input.payload.pull_request.head.repo.clone_url,
			"revision": input.payload.pull_request.head.sha,
			"branch": branch,
			"fullName": input.payload.repository.full_name,
		}
  }
}

event = e {
  input.headers["X-Github-Event"][_] = "push"
	repo = lower(input.payload.repository.name)
	branch = sanitize_branch(trim_prefix(input.payload.ref, "refs/heads/"))
	namespace = sprintf("pipeline-%s-%s", [repo, branch])
	e := {
		"eventType": "push",
		"eventAction": "push",
    "namespace": namespace,
		"repository": {
			"name": repo,
			"url": input.payload.repository.clone_url,
			"revision": input.payload.head_commit.id,
			"branch": branch,
			"fullName": input.payload.repository.full_name,
		}
  }
}

event = e {
  input.headers["X-Gitlab-Event"][_] = "Push Hook"
	repo = lower(input.payload.project.name)
	branch = sanitize_branch(trim_prefix(input.payload.ref, "refs/heads/"))
	namespace = sprintf("pipeline-%s-%s", [repo, branch])
  e := {
    "eventType": "push",
    "eventAction": "push",
    "namespace": namespace,
    "repository": {
      "name": repo,
      "url": input.payload.repository.git_http_url,
      "revision": input.payload.checkout_sha,
      "branch": branch,
      "fullName": input.payload.project.path_with_namespace
    }
  }
}

event = e {
  input.headers["X-Gitlab-Event"][_] = "Merge Request Hook"
	repo = lower(input.payload.project.name)
	branch = sanitize_branch(input.payload.object_attributes.source_branch)
	namespace = sprintf("pipeline-%s-%s", [repo, branch])
  e := {
    "eventType": "pull_request",
    "eventAction": input.payload.object_attributes.state,
    "namespace": namespace,
    "repository": {
      "name": repo,
      "url": input.payload.object_attributes.source.git_http_url,
      "revision": input.payload.object_attributes.last_commit.id,
      "branch": branch,
      "fullName": input.payload.object_attributes.source.path_with_namespace
    }
  }
}


default run_stage1 = false
run_stage1 {
	event.eventType = "pull_request"
	event.eventAction = "opened"
}
run_stage1 {
	event.eventType = "pull_request"
	event.eventAction = "updated" # gitlab
}
run_stage1 {
	event.eventType = "pull_request"
	event.eventAction = "synchronized" # github
}
run_stage1 {
	event.eventType = "push"
	event.repository.branch = "master"
}

default t = false
resources[t] {
	run_stage1
	t := stage1Task
}

resources[t] {
	event.eventType = "pull_request"
	event.eventAction = "closed"
	t := deleteNSTask
}
