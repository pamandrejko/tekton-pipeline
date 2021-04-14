# README

## Purpose
The purpose of this example is to walkthrough the creation of a simple Tekton pipeline on Openshift. This is example is for those interested in learning more beyond the Tekton pipeline [HelloWorld tutorial](https://tekton.dev/docs/getting-started/
).

### Scenario

Tekton pipelines can be used to manage a variety of tasks, and in fact OpenShift includes a set of pre-defined pipelines for quickly getting started and customizing according to your use case. But the goal of this example is to understand each of the components required to build a pipeline. So in this scenario we create a Tekton pipeline to post a message to a Slack channel, every time a commit is made to a GitHub repository.

**Disclaimer:** There are many better, simpler, and easier ways to post a message to a Slack channel when a commit is made to a GitHub repo, for example by using Travis. But we use this scenario as a simple learning exercise.


## Background

This tutorial assumes you have a basic knowledge of Tekton pipelines, namely that you are familiar with the [HelloWorld tutorial](https://tekton.dev/docs/getting-started/).

We take that tutorial one step further by adding an EventListener, TriggerBinding, and TriggerTemplate:


![Overview diagram](https://github.ibm.com/pamandrejko/tekton-pipeline/blob/main/config/images/Tekton-Pipelines-primer-1.png)

In this example, we monitor for `push` events emitted from a GitHub webhook to an `EventListener` on our OpenShift cluster. The eventlister includes a `TriggerBinding` which defines the data (fields) from the event that we are interested in. It also includes a `TriggerTemplate` which defines what to do when the event is received, in our case to kickoff our pipeline. The pipeline contains a single task that posts a message to slack that includes the name of the commit author.

## Prerequisites

Before attempting this tutorial you need to complete a few simple steps.

### Install the GitOps operator

The OpenShift GitOps operator must be installed on your cluster. It's included in your catalog, so all you need to do after logging into your console is go to **Operators** > **OperatorHub** and search for **GitOps**. Click the tile named Red Hat OpenShift GitOps and then click **Install**. Installing the operator adds a **Pipelines** section to the left nav of your OpenShift web console and creates the `pipeline` ServiceAccount which we will use in our pipeline.


### Create a Slack App

You need to create a Slack App, a simple application that is used to connect your pipeline to Slack. **Note:** This application has nothing to do with Tekton pipelines, rather is it just part of the scenario we are using in our example. It's a simple request that requires no coding!

Visit [Create a Slack App](https://api.slack.com/apps?new_app=1) to request a new slack app in your workspace. A URL is generated that is required in the next step when we configure some secrets.  You will also need to select the Slack channel that you want to use for the App.

### Create secrets

Two secrets are required by this solution:

- **Slack secret** - The `slack-webhook-secret` contains the URL of your Slack app.
- **Webhook secret** - The `web-hook-secret-key` secret contains the value that is used by your GitHub repository webhook to authenticate with your event listener. This string value needs to be BASE64 encoded in the secret. (If you are unsure how to do that, there are many utilities available online to base64 encode a string.)

So before you can apply the yamls in this repository to your OpenShift cluster, you need to edit the two `yaml` files:

1. Edit the https://github.ibm.com/pamandrejko/tekton-pipeline/blob/main/config/cicd-slack/01b-slack-webhook-secret.yaml file and add the URL of your SlackApp.
2. Edit the https://github.ibm.com/pamandrejko/tekton-pipeline/blob/main/config/cicd-slack/01c-web-hook-secret-key.yaml file and provide a BASE64 encoded string which you will provide when you configure the webhook on your Git repository. This value is used to secure the communications between your cluster and the webhook. 


### Create a project

While not technically required, a namespace partitions our objects into their own project making them easier locate and work with.

After logging in to your OpenShift cluster form the command line, run the following command to create a project:

```
cd config/cicd-slack
oc apply -f 01a-webhook-to-slack-pipeline-environment.yaml
```


## Build the Tekton pipeline

Now we are ready to build the component that form our pileline. We create `yamls` for each component of the pipeline. In total there are six components required:
- Task
- Pipeline
- TriggerBinding
- TriggerTemplate
- EventListener

Lastly, you need to configure a **webhook** on your GitHub repository. The webhook enables your repository to emit events to your EventListener. Let's walk through these steps.

### Create a task

We begin by creating a task for our pipeline, namely posting a messsage to Slack. Before you write a new task, check out the [Tekton task catalog](https://github.com/tektoncd/catalog) to see if one already exists for what you want to do. In our case, a task to [post a message to slack](https://raw.githubusercontent.com/tektoncd/catalog/main/task/send-to-webhook-slack/0.1/send-to-webhook-slack.yaml) already exists that we can use. If you examine our [task definition](https://github.ibm.com/pamandrejko/tekton-pipeline/blob/main/config/cicd-slack/02-task-send-to-webhook-slack.yaml) you can see it contains a single step that posts a message to Slack by using the `slack-webhook-secret` which contains the Slack app URL.  

Run the following command to create the task:

```
oc apply -f 02-task-send-to-webhook-slack.yaml
```

The task is visible from the OpenShift web console if you navigate to **Pipelines** > **Tasks**.

You can verify that this task works by creating a TaskRun object:
```
oc apply -f test/99-run-task-run-send-to-webhook-slack.yaml
```

Check your Slack channel to confirm that the message was posted.

### Create a pipeline

Next we create the [pipeline](https://github.ibm.com/pamandrejko/tekton-pipeline/blob/main/config/cicd-slack/03-pipeline-post-to-slack-pipeline-with-parms.yaml) which invokes our task. Notice the pipeline definition includes the task name and specifies two parameters: the `slack-webhook-secret` and the contents of the `message` that we want to post to slack.   


We'd also like that message to include the **name of the person who authored the commit**, a piece of data that is available in the `push` event from the GitHub repo. So we define that `COMMIT_AUTHOR` as a parameter of the pipeline itself, under the `params:` section.

Run the following command to create the pipeline:

```
oc apply -f 03-pipeline-post-to-slack-pipeline-with-parms.yaml
```

The pipeline is visible from the OpenShift web console if you navigate to **Pipelines** > **Pipelines**.

### Create a TriggerBinding

The trigger binding defines which fields in the GitHub repo event that we are interested in using. Our [example](https://github.ibm.com/pamandrejko/tekton-pipeline/blob/main/config/cicd-slack/04-binding-github-push-binding.yaml) only uses the `body.head_commit.author.name` field from the event. But a few others are included in the binding so that you can see other types of data that are available.

Run the following command to create the TriggerBinding:

```
oc apply -f 04-binding-github-push-binding.yaml
```

The TriggerBinding is visible from the OpenShift web console if you navigate to **Pipelines** > **Triggers** > **TriggerBindings**.

### Create a TriggerTemplate

The TriggerTemplate launches the pipeline. If you remember the PipelineRun from the HelloWorld tutorial, the TriggerTemplate causes a PipelineRun to occur. In fact, if you examine the [trigger definition](https://github.ibm.com/pamandrejko/tekton-pipeline/blob/main/config/cicd-slack/05-template-github-push-template-with-parms.yaml) you'll notice it contains a `PipelineRun` section. When the trigger fires:
-  A pod is deployed with the name `post-to-slack-pipeline-with-parms-$(uid)` that invokes the task.
- It extracts the commit author from the event via the `io.openshift.build.commit.author` parameter and passes that to the pipeline using the `COMMIT_AUTHOR` parameter.
- Notice that the `pipeline` service account is associated with the pod. This is the service account that was created when the Red Hat OpenShift GitOps operator was deployed.

Run the following command to create the TriggerTemplate:

```
oc apply -f 05-template-github-push-template-with-parms.yaml
```

The TriggerTemplate is visible from the OpenShift web console if you navigate to **Pipelines** > **Triggers** > **TriggerTemplates**.


### Create an EventListener

Finally, we tie all of this together with the [EventListener definition](https://github.ibm.com/pamandrejko/tekton-pipeline/blob/main/config/cicd-slack/06-event-listener-webhook-to-slack-pipeline-event-listener.yaml).

The EventListener references the TriggerTemplate and the TriggerBinding that we created. The `interceptors:` section filters the events that are emitted to only look at `push` events and also ensures that the events are coming from the correct GitHub repository.

**Reminder:** If you want to try this out with your own repository you need to modify the name of the GitHub repo in this yaml.  Change `body.repository.full_name == 'cloudpakbringup/bringup-site'` to point to your GitHub repo.

Run the following command to create the EventListener:

```
oc apply -f 06-event-listener-webhook-to-slack-pipeline-event-listener.yaml
```

The EventListener is visible from the OpenShift web console if you navigate to **Pipelines** > **Triggers** > **EventListeners**.

#### Expose the EventListener route

The GitHub webhook will post event to our event listeners, so we have to expose our event listener as a route on our cluster.

Run the following command to create the route:

```
oc apply -f 07-route-gitops-webhook-event-listener-route.yaml
```

The EventListener route is visible from the OpenShift web console if you navigate to **Networking** > **Routes**. (You may want to filter the view by your project only.)

### Create the Webhook

Now we have to tell the webhook where to send the events, the address of our event listener.

1. Run the following command to get the URL for the route:

  ```
  oc get route
  ```

  The output looks similar to:
  ```
  NAME                                  HOST/PORT                                                                                       PATH   SERVICES                              PORT   TERMINATION   WILDCARD
  gitops-webhook-event-listener-route   gitops-webhook-event-listener-route-webhook-to-slack-pipeline.apps.pa-tekton-to-slack.cp.fyre.ibm.com
  ```
  The route URL is therefore `gitops-webhook-event-listener-route-webhook-to-slack-pipeline.apps.pa-tekton-to-slack.cp.fyre.ibm.com`.

2. Navigate to your GitHub repo and click **Settings** > **Hooks**. Click **Add webhook**.
  - In the **Payload url** field, paste in the address of the event listener, beginning with `http://`.
  - Change the `content-type` to `application/json`.
  - Paste in the value of the non-BASE64 encoded secret that you specified for the  `web-hook-secret-key`.
  - Click **Add webhook**.

At this point your Webhook and Tekton pipeline are configured to post a message to your slack channel when a commit is made to your GitHub repository.

## References

Credit goes to Denilson Nastacio for his [GitOps repository](https://github.ibm.com/cloudpakbringup/gitops) which provided the basic process and flow for this tutorial.


Tekton has excellent examples of [pipelines](https://github.com/tektoncd/pipeline/tree/main/examples), [triggers, templates, and bindings](https://github.com/tektoncd/triggers/tree/main/examples) that are useful when creating your own.
