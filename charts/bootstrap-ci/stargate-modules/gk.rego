package gk

event = e {
  input.headers["X-Github-Event"][_] = "pull_request"
	repo = lower(input.payload.repository.name)
	e := {
		"eventType": "pull_request",
        "eventAction": input.payload.action,
		"repository": {
            "id": sprintf("pr-%d", [input.payload.pull_request.number]),
			"name": repo,
			"url": input.payload.pull_request.head.repo.clone_url,
			"revision": input.payload.pull_request.head.sha,
	        "branch": input.payload.pull_request.head.ref,
			"fullName": input.payload.repository.full_name,
		}
  }
}

event = e {
  input.headers["X-Github-Event"][_] = "push"
	repo = lower(input.payload.repository.name)
	branch = trim_prefix(input.payload.ref, "refs/heads/")
	e := {
		"eventType": "push",
		"eventAction": "push",
		"repository": {
            "id": branch,
			"name": repo,
			"url": input.payload.repository.clone_url,
			"revision": input.payload.head_commit.id,
			"branch": branch,
			"fullName": input.payload.repository.full_name,
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
	event.eventAction = "synchronized" # github
}
run_stage1 {
	event.eventType = "push"
	event.repository.branch = "master"
}

default superuser = false
superuser {
	event.eventType = "push"
	event.repository.branch = "master"
}

default t = false
resources[r] {
	run_stage1
    saName = sprintf("ci-%s-%s", [event.repository.name, event.repository.id])
    roleName = sprintf("ci-role-%s-%s", [event.repository.name, event.repository.id])
    taskName = sprintf("ci-stage2-%s-%s-", [event.repository.name, event.repository.id])
	r := [
    {
      "apiVersion": "v1",
      "kind": "ServiceAccount",
      "metadata": {
        "name": saName,
        "namespace": "tekton-pipelines",
        "annotations": {
          "ci/superuser": sprintf("%s", [superuser])
        }
      }
    },
    {
      "apiVersion": "rbac.authorization.k8s.io/v1beta1",
      "kind": "ClusterRoleBinding",
      "metadata": {
        "name": roleName,
      },
      "roleRef": {
        "apiGroup": "rbac.authorization.k8s.io",
        "kind": "ClusterRole",
        "name": "tekton-ci-stage2"
      },
      "subjects": [
        {
          "kind": "ServiceAccount",
          "name": saName,
          "namespace": "tekton-pipelines"
        }
      ]
    },
    {
      "apiVersion": "tekton.dev/v1alpha1",
      "kind": "TaskRun",
      "metadata": {
        "generateName": taskName,
        "namespace": "tekton-pipelines"
      },
      "spec": {
        "serviceAccount": saName,
        "taskRef": {
          "name": "ci-stage2-ng"
        },
        "inputs": {
          "params": [
            { "name": "event", "value": json.marshal(event) },
            { "name": "repoName", "value": event.repository.name },
            { "name": "repoID", "value": event.repository.id }
          ],
          "resources": [
            {
              "name": "project-repo",
              "resourceSpec": {
                "type": "git",
                "params": [
                  {
                    "name": "url",
                    "value": event.repository.url
                  },
                  {
                    "name": "revision",
                    "value": event.repository.revision
                  }
                ]
              }
            }
          ]
        }
      }
    }
  ]
}
