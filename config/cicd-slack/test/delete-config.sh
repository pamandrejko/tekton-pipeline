#!/bin/bash

##################
### PARAMETERS ###
##################
source env.sh
oc project $OCP_NAMESPACE
oc delete route gitops-webhook-event-listener-route
oc delete eventlistener webhook-to-slack-pipeline-event-listener
oc delete triggertemplate github-push-template-trigger-with-parms
oc delete triggerbinding github-push-binding
oc delete pipeline post-to-slack-pipeline-with-parms
oc delete task send-to-webhook-slack
oc delete secret web-hook-secret-key
oc delete secret slack-webhook-secret
oc project default
oc delete project $OCP_NAMESPACE
