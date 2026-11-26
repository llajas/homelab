---
name: {{ include "hermes-agent.team.skillName" . }}
description: Manage the {{ .Values.team.name }} Hermes team roster, leader and member responsibilities, member status, {{ include "hermes-agent.team.platformLabel" . }} handoffs, reviews, and shared knowledge. Use for any team, member, roster, online-status, delegation, handoff, or collaboration request.
---

# {{ .Values.team.name }} team protocol

Your identity and assigned role come from the runtime environment hint. Follow
only the workflow matching that role. This one shared skill is mounted by every
configured team release.

## Roster

| Name | Team role | Capabilities |
|---|---|---|
| {{ .Values.team.leader.name }} | Leader | Task decomposition, assignment, review, and final synthesis |
{{- range .Values.team.members }}
| {{ .name }} | {{ .role | replace "|" "\\|" }} | {{ if .capabilities }}{{ join ", " .capabilities }}{{ else }}Not specified{{ end }} |
{{- end }}

The roster states who is configured. It does not prove runtime availability.
Never infer that a member is online, idle, or working from {{ include "hermes-agent.team.platformLabel" . }}'s typing
indicator. Treat only an explicit team `TASK`, `RESULT`, or `BLOCKED` message
as authoritative workflow state.

## Shared knowledge

The shared volume is mounted at `{{ .Values.team.sharedVolume.mountPath }}`.
The leader is its curator and may write durable, reviewed, reusable knowledge.
Members receive a read-only mount and may consult it as background.
Never use the volume for live assignments, queues, locks, progress, completion
markers, or result handoffs. {{ include "hermes-agent.team.platformLabel" . }} messages must contain all context required
to perform and review a task.

## Leader workflow

1. On the first delegation, start the same outbound message with one brief
   human-facing acknowledgement and a one-sentence plan. Do not send a
   standalone no-mention acknowledgement, because that would leave no team
   event to continue the run. Then decompose the request.
2. Choose exactly one suitable member. Send one message containing that
   member's exact mention, complete context, one concrete task, observable
   acceptance criteria, and this final marker:

   `[TEAM run=<short-id> step=<n> TASK]`

   That message is your own normal reply, and it is the handoff. No tool is
   needed or exists for delegating. Not having a messaging tool does not mean
   you cannot delegate, so never tell the human that the capability is missing.

3. Wait for that member's matching `RESULT` or `BLOCKED` response. Do not infer
   progress from typing state and do not mention another member while waiting.
4. Review the result. Request one concrete revision from the same member when
   needed. For a dependent follow-up, hand the accepted result and full context
   to the next member.
5. When the next task is an independent review, provide the original goal,
   acceptance criteria, and candidate conclusion, but withhold the earlier
   member's method and detailed trace until the reviewer responds. Do not
   suggest a verification method. Complete context means everything needed to
   perform the review, not the evidence that must be independently reproduced.
6. Preserve the run id and increment the step. Never exceed
   **{{ .Values.team.protocol.maxHandoffs }}** member handoffs. Escalate to the
   human without a member mention when the limit would be exceeded.
7. When the goal is complete, provide the human-facing synthesis with no member
   mention. A no-mention final response terminates the workflow.

Never mention two members at once. Never emit filler containing a member
mention. Do not use `delegate_task` as a substitute for assigning a configured
team member: it creates an anonymous child, not one of the rostered agents.

## Member workflow

1. Act only on a leader message containing your exact mention and a
   `[TEAM ... TASK]` marker.
2. Perform the visible task against its acceptance criteria. Do not delegate to
   another configured member and do not use the shared volume as a message bus.
   For an independent review, choose your own method without relying on an
   earlier member's trace; if one was included, explicitly ignore it.
3. Return exactly one complete response to the leader. Begin it with the
   leader's exact mention, {{ include "hermes-agent.team.mention" (list (.Values.team.platform | default "discord") .Values.team.leader) }}: the leader only sees a response that mentions it,
   so a response without the mention is lost. Include evidence,
   assumptions, and caveats, then finish with the matching marker:

   `[TEAM run=<same-id> step=<same-n> RESULT]`

4. If blocked, return one precise question and the same metadata with
   `BLOCKED`. Mention the leader exactly once and never mention another member.
{{- with .Values.team.skill.extraInstructions }}

## Deployment-specific instructions

{{ . }}
{{- end }}
