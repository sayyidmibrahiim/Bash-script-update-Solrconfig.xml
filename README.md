<div align="center">

# SolrConfig Bulk Update Automation

**A case study in repeatable SolrCloud configuration changes and manual rollback.**

![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat-square) ![SolrCloud](https://img.shields.io/badge/SolrCloud-2563eb?style=flat-square) ![Status-Learning Archive](https://img.shields.io/badge/Status-Learning_Archive-e18536?style=flat-square)

[Workflow](#what-the-scripts-do) · [Assumptions](#environment-assumptions) · [Risks](#important-limitations) · [Files](#repository-files)

</div>

---

A Bash automation experiment for modifying the same `solrconfig.xml` block across multiple Apache Solr Cloud configsets, while keeping a local backup that can be used for rollback.

This repository is an older operational script and is published as a **learning / automation case study**, not as production-ready tooling.

---

## Why I Built It

The original problem was repetitive configuration work.

A Solr environment had multiple configsets that required the same change to `solrconfig.xml`. Updating each one manually would mean repeatedly:

1. locating the configset,
2. downloading its `solrconfig.xml`,
3. editing the same XML block,
4. uploading the modified file,
5. reloading the affected Solr collection,
6. and keeping a backup in case rollback was needed.

The idea behind these scripts was to turn that sequence into a repeatable workflow.

---

## What the Scripts Do

The repository contains two scripts.

### `scriptRemoveSomeSolrConfig.sh`

This is the preparation stage.

At a high level it:

```text
Discover local Solr / ZooKeeper information
        ↓
List entries under zk:/configs/
        ↓
Download each solrconfig.xml
        ↓
Keep an untouched backup
        ↓
Create a working copy
        ↓
Format the XML with xmllint
        ↓
Remove the targeted suggestion-handler block
        ↓
Check whether the marker still exists
```

The script stores the original files under:

```text
solrconfig-bkp/<configset>/solrconfig.xml
```

and the modified copies under:

```text
solrconfig-edited/<configset>/solrconfig.xml
```

It also creates `list.txt` from the entries returned by the Solr ZooKeeper CLI.

### `update-rollback.sh`

This was intended as the deployment / rollback stage.

Its intended workflow is:

```text
UPDATE
modified local solrconfig.xml
        ↓
copy to ZooKeeper configset
        ↓
reload collection

ROLLBACK
backup solrconfig.xml
        ↓
copy back to ZooKeeper configset
        ↓
reload collection
```

The original implementation also leaves the backup on disk so the configuration is not overwritten without a recovery copy.

---

## What Is Being Removed

The preparation script looks for this marker:

```xml
<!-- suggestion request handler -->
```

and deletes that line plus the next 24 lines from the formatted XML.

The original target was a suggestion / spell-check configuration containing a `SpellCheckComponent` and `/suggest` request handler.

This is important: the script does **not** parse the XML semantically. It removes a fixed line range after locating a text marker.

---

## Environment Assumptions

The scripts assume a Linux-hosted Solr Cloud environment with local access to Solr and ZooKeeper process information.

They depend on tools and commands including:

- Bash
- Apache Solr CLI
- ZooKeeper-backed Solr configsets
- `jcmd`
- `ps`
- `awk`
- `grep`
- `sed`
- `xmllint`
- `curl`

The code attempts to discover values such as the ZooKeeper client port, local IP address, Solr directory, and Solr port from running processes rather than receiving them as explicit configuration.

---

## Important Limitations

This code reflects how I approached the problem at the time. Reviewing it now, there are several things I would design differently before using the same idea in a production environment.

### 1. Process parsing is brittle

The scripts derive the Solr directory and port using positional `awk` fields from `ps` output.

For example, values are extracted from fields such as `$49` and `$41`.

That depends on the exact JVM command-line layout and can break if the process arguments change.

A stronger implementation would use explicit configuration or robust argument parsing.

### 2. `zk:/configs/` is a configset list, not necessarily a collection list

The script calls:

```bash
solr zk ls zk:/configs/
```

and treats each returned entry as a collection.

In Solr Cloud, entries under `/configs` are configsets. A configset name may match a collection name in a particular environment, but that relationship should not be assumed generically.

A production version should explicitly resolve which collections use which configsets.

### 3. XML modification is line-based

The script searches for a comment and deletes a fixed 25-line range.

That works only while the XML structure around that marker stays exactly as expected.

A safer implementation would modify the XML structurally, for example with an XML-aware tool or parser, and verify the exact nodes being removed.

### 4. Re-running the preparation script is not idempotent

Directories such as `solrconfig-bkp` and `solrconfig-edited` are created with plain `mkdir` and there is no run-specific workspace or cleanup strategy.

Repeated runs can therefore collide with artifacts from an earlier run.

### 5. Error handling is minimal

Many commands either suppress output or continue without checking exit status.

There is no fail-fast behavior, transaction boundary, per-configset result summary, or automatic stop when one upload / reload fails.

### 6. The update / rollback argument validation contains a bug

`update-rollback.sh` tells the user to run:

```bash
./upload-rollback.sh update
./upload-rollback.sh rollback
```

and its execution branches also check for `update` and `rollback`.

However, the earlier argument validator accepts only:

```text
upload
reload
```

As written, `update` and `rollback` are rejected before the intended branches can run.

This means the second script should **not be treated as working deployment tooling in its current committed state**.

### 7. The rollback Solr CLI path is inconsistent

The update path uses:

```text
$solr_dir/bin/solr
```

while the rollback branch uses:

```text
$solr_dir/solr/bin/solr
```

That additional `/solr` appears inconsistent with how `solr_dir` is discovered and with the update branch. It would need verification in the target environment before use.

### 8. Credentials should not live in the command

The reload call contains placeholder basic-auth values directly in the `curl` command.

A modern version should load secrets from an appropriate secret source or protected environment variables rather than putting credentials in the script.

---

## What I Would Build Differently Today

If I rebuilt this workflow now, I would preserve the core idea but change the implementation substantially:

```text
Explicit environment/config input
        ↓
Discover collection → configset relationships
        ↓
Pre-flight validation
        ↓
Create timestamped backup workspace
        ↓
Download current config
        ↓
Parse and modify XML structurally
        ↓
Generate diff / verification report
        ↓
Require or record approval
        ↓
Upload one configset at a time
        ↓
Verify result
        ↓
Reload affected collections
        ↓
Record success / failure per target
        ↓
Offer deterministic rollback from backup
```

I would also make operations idempotent where possible and stop automatically when verification fails instead of continuing across every target.

---

## What This Project Represents

This is a small script, but it captures a pattern that has followed me throughout my work:

> When I see the same operational change being repeated across many targets, I start looking for a way to make the process repeatable and recoverable.

The useful part was not only replacing manual edits with a loop.

The workflow already contained the beginnings of several ideas that matter more in larger automation systems:

- discover the targets,
- preserve the previous state,
- generate a modified working copy,
- verify the change,
- deploy consistently,
- keep a rollback path.

The implementation is old and imperfect, and I prefer documenting those limitations rather than presenting it as something it is not.

That contrast is also useful to me: it shows how my approach to automation has evolved from **"script the repeated steps"** toward **"design the failure, verification, and recovery behavior as part of the system."**

---

## Repository Files

```text
.
├── scriptRemoveSomeSolrConfig.sh   # backup + prepare modified configs
├── update-rollback.sh              # intended update / rollback stage
└── README.md
```

---

## Status

**Historical / learning project.**

The repository is kept public as an example of early Bash-based operational automation and how I now review older automation more critically.

Do not run these scripts against a production Solr environment without reviewing and correcting the limitations documented above.
