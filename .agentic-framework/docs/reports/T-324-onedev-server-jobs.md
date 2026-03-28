# OneDev Server-Level / Project-Level Build Jobs Research

**Date:** 2026-03-05
**Question:** Can OneDev define CI/CD build jobs outside the `.onedev-buildspec.yml` file in the repository?

## Executive Summary

**No.** OneDev fundamentally ties build specifications to the repository file `.onedev-buildspec.yml`. There is no server-level, project-settings-level, or admin-level mechanism to define build jobs outside this file. The filename and path are hardcoded in the Java source code as a compile-time constant. The closest workaround is cross-project build spec import, available since OneDev 4.3.

---

## Question 1: Can OneDev define build jobs in the project settings UI (not in the repo file)?

**No.** Build jobs can only be defined in `.onedev-buildspec.yml` in the repository root. The project settings UI provides:
- **Job secrets** (credentials referenced by buildspec)
- **Build preserve days** (retention policy)
- **Job executor assignment**

But there is **no UI for defining jobs, pipelines, or triggers outside the buildspec file**. The "build spec editor" in the UI is a GUI editor for the `.onedev-buildspec.yml` file itself -- it writes back to the repo file, not to server-side storage.

**Source:** [OneDev Concepts](https://docs.onedev.io/concepts): "Build spec describes specification of build processes in OneDev. It is defined in file `.onedev-buildspec.yml` in root of the repository."

## Question 2: Is there a "default buildspec" or "server buildspec" feature?

**No.** There is no server-wide or organization-wide default buildspec. OneDev does not have a feature equivalent to:
- GitLab's `default:` pipeline or instance-level CI/CD variables with templates
- Jenkins' shared libraries or global pipeline definitions
- GitHub Actions' organization-level reusable workflows

If a repository does not contain `.onedev-buildspec.yml`, OneDev simply prompts the user to create one. There is no fallback to a server-defined default.

**Source:** [OneDev Quickstart](https://docs.onedev.io/): "If your Git repository does not contain a build spec file, OneDev will prompt you to create one."

## Question 3: Can OneDev use a buildspec from a different branch or path?

**No, with a very specific design rationale.** OneDev's maintainer (Robin Shen) explicitly stated this is by design:

> "Whenever a commit is involved in CI/CD, only its associated build spec is used. [...] CI/CD logic living together with code."

This means:
- A trigger on branch `master` will ONLY read the buildspec from the `master` branch commit
- You cannot have branch `prod` define a job that triggers when `master` is updated (unless `master` also has that buildspec)
- There is no "use buildspec from default branch" option

**Source:** [OD-1778: Branch update trigger from branch without .onedev-buildspec.yml](https://code.onedev.io/onedev/server/~issues/1778) -- Closed as working-as-designed.

## Question 4: Can you configure the buildspec filename/location in project settings?

**No.** The filename is hardcoded as a Java compile-time constant in the source code:

```java
// BuildSpec.java, line 90
public static final String BLOB_PATH = ".onedev-buildspec.yml";
```

This is `public static final` -- there is no configuration property, environment variable, or project setting to change it. The only way to change the filename would be to fork OneDev and modify the source code.

**Source:** [BuildSpec.java on GitHub](https://github.com/theonedev/onedev/blob/main/server-core/src/main/java/io/onedev/server/buildspec/BuildSpec.java)

## Question 5: What OneDev version introduced which features?

| Version | Feature |
|---------|---------|
| Early versions | Build spec in `.onedev-buildspec.yml` (core design since inception) |
| **4.3** (2021) | **Cross-project build spec import** -- import buildspecs from other projects with tag-based versioning |
| 4.3+ | Property overrides and step template parameters for imported specs |
| Current (11.x) | No changes to the fundamental "buildspec in repo" architecture |

**Source:** [CI/CD configuration reuse in OneDev (dev.to)](https://dev.to/robinshine/ci-cd-configuration-reuse-in-onedev-5c0i)

---

## Workaround: Cross-Project Build Spec Import (Best Available Alternative)

Since OneDev 4.3, you can achieve a **centralized-ish** configuration using build spec imports:

1. **Create a "commons" project** with shared jobs, step templates, and services in its `.onedev-buildspec.yml`
2. **Tag releases** of the commons project (e.g., `v1`, `v2`)
3. **Import in other projects** -- each project's buildspec declares an import from the commons project at a specific tag
4. **Override selectively** -- local definitions override imported ones with the same name; property placeholders allow per-project customization

**Limitations:**
- Every consuming project still needs its own `.onedev-buildspec.yml` (even if it only contains an import statement)
- The import must be explicitly declared in each project -- there is no "auto-inherit" from a parent project
- Updating the shared spec requires creating a new tag and updating imports in each consuming project

**Source:** [Build Spec Reuse Documentation](https://docs.onedev.io/tutorials/cicd/reuse-buildspec)

---

## Comparison with Other CI/CD Systems

| Feature | OneDev | GitLab | Jenkins | GitHub Actions |
|---------|--------|--------|---------|----------------|
| Jobs defined in repo file | Yes (only way) | Yes (primary) | Optional (Jenkinsfile) | Yes (primary) |
| Server/org-level job definitions | **No** | Yes (instance CI/CD) | Yes (shared libraries, global config) | Yes (org reusable workflows) |
| Configurable spec filename | **No** (hardcoded) | No (`.gitlab-ci.yml`) | Yes (configurable) | No (`.github/workflows/*.yml`) |
| Use spec from different branch | **No** (by design) | Yes (`include:`) | Yes (multibranch) | Yes (`workflow_call`) |
| Cross-project spec sharing | Yes (import since 4.3) | Yes (`include: project:`) | Yes (shared libraries) | Yes (reusable workflows) |
| Default/fallback spec | **No** | Yes (`default:` keyword) | Yes (global shared lib) | No |

---

## Conclusion

OneDev's architecture is firmly committed to "CI/CD logic living together with code." The buildspec is always in `.onedev-buildspec.yml` in the repository root, always read from the commit being processed, and the filename cannot be configured. The cross-project import mechanism (since v4.3) is the only way to centralize common CI/CD definitions, but it still requires each project to have its own buildspec file with at least an import declaration.
