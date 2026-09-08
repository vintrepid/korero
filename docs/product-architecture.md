# Product architecture

## The whole package

Korero is the embeddable client as well as the workflow engine. Installing and
configuring it should provide the shared UI, messages, tasks, and communication
experience—not a collection of backend pieces that every application must turn
into its own email client. The present alpha only supplies the task/execution
foundation; this document records the boundary we are building toward.

Email-client familiarity is a starting point, not a limit. SMS, in-app messages,
voice recordings, files, and future channels belong in one workspace. A person
should be able to see a conversation, its artifacts, and the work it creates
without switching among separate applications.

## Explore meaning, not storage bins

Folders evolve into a classifier and ontology explorer. Topics, interests,
people, relationships, and events connect material across channels and formats.
An item can belong in several contexts without duplicating it or forcing its
owner to choose one filing location. File type and transport remain useful
filters, not the primary information architecture.

Navigation represents queries and relationships over current Ash resources.
An Inbox is an attention view; a topic is a contextual view; a conversation is
a related sequence of communication. None needs to be the physical owner of
every item it displays. Semantic zoom should progressively reveal content,
context, work, history, and sharing controls while preserving orientation.

These names identify distinct concerns, not a mandate for one generic table:

- **Message/conversation:** communication, participants, receipt/read state,
  replies, and thread relationships. Delivery attempts belong to channels.
- **Task:** requested work, lifecycle, assignment, schedule, and outcome.
  An attached resource retains its typed domain actions and authorization.
- **Artifact:** a file, recording, or other content with provenance, versions,
  storage references, and access controls. A transcript is not its original audio.
- **Topic/interest:** a concept or a person's interest in it, connected through
  many-to-many associations rather than an exclusive folder path.
- **Event:** a happening that provides context for related communication and
  artifacts; it is not automatically a Logger observation or journal entry.
- **Classification:** an explicit association with provenance. Human decisions
  and future automated suggestions must be distinguishable and correctable.

Generic tags and their relationships may support this explorer, but domain
behavior remains in explicit resources/actions. A topic must not acquire
executable behavior merely because a classifier assigned a label.

## Ownership

Korero owns the reusable client UI, interaction model, message/task contracts,
channel-adapter contracts, and artifact/classification navigation. The host
supplies identity, authorization, tenancy, persistence configuration, provider
credentials, branding/theme, mount points, and typed business actions.

The UI should be composed from reusable semantic components and app-level theme
tokens, with Ash-aware Cinder lists where sorting/filtering/tabular interaction
is appropriate. Shared Phoenix/Ash infrastructure belongs in its owning
component/tool library. Hosts mount/configure this experience rather than copy
its implementation. Business transitions remain Ash actions, not LiveView event
handlers. Installation and migration wiring should be automated by an installer.

Oban remains the execution engine. JournalAsh owns its observation/journal
boundary. SolidAsh provides the private-data integration boundary; encryption,
key ownership, recovery, and grants must be explicitly designed. Korero never
depends back on AshLotus or a host application.

## Privacy is independent of classification

Topics, saved searches, navigation links, and shared folders never grant access.
Every view applies the requesting actor's resource and participant policies
before returning items, counts, previews, or relationships. Public research
material and a person's private interest in it are different records with
different visibility. Sharing one must not silently publish the other.

Private content promised to be unreadable by the service must remain encrypted
on the server. It cannot be decrypted into server-side LiveView assigns or
templates; authorized clients perform that work. Server-side search,
classification, previews, and AI processing cannot silently defeat that promise.
Server-held Cloak keys provide encryption at rest, not this stronger guarantee.

## Delivery path

1. Extract a real existing client experience behind explicit host contracts,
   preserving participant authorization, native Ash actions, and live updates.
2. Package the UI, semantic styles/assets, routing/mount instructions, and an
   installer. Prove a representative host can mount it without copying views.
3. Unify message, task, delivery, and artifact integration without collapsing
   their separate lifecycles or losing source identities.
4. Evolve folder navigation into topic/interest/event classification, preserving
   existing links and actor-specific visibility throughout the transition.

These are implementation steps, not claims that the alpha already supplies
them. Prefer model/adapter behavior tests, a few high-level UI acceptance checks,
and a representative host integration over many view-specific tests.
