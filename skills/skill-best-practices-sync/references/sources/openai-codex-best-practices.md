If you’re new to Codex or coding agents in general, this guide will help you get better results faster. It covers the core habits that make Codex more effective across the CLI, IDE extension, and the ChatGPT desktop app, from prompting and planning to validation, MCP, skills, and scheduled tasks.


Codex works best when you treat it less like a one-off assistant and more like a teammate you configure and improve over time.


A useful way to think about this: start with the right context for the task, use `AGENTS.md` for durable guidance, configure Codex to match your workflow, connect external systems with MCP, turn repeated work into skills, and automate stable workflows.


## Strong first use: Context and prompts


Codex is already strong enough to be useful even when your prompt isn't perfect. You can often hand it a hard problem with minimal setup and still get a strong result. Clear prompting isn't required to get value, but it does make results more reliable, especially in larger codebases or higher-stakes tasks.


If you work in a large or complex repository, the biggest unlock is giving Codex the right context for the task and a clear structure for what you want done.


A good default is to include four things in your prompt:


- Goal: What are you trying to change or build?

- Context: Which files, folders, docs, examples, or errors matter for this task? You can @ mention certain files as context.

- Constraints: What standards, architecture, safety requirements, or conventions should Codex follow?

- Done when: What should be true before the task is complete, such as tests passing, behavior changing, or a bug no longer reproducing?


This helps Codex stay scoped, make fewer assumptions, and produce work that's easier to review.


Choose a reasoning level based on how hard the task is and test what works best for your workflow. Different users and tasks work best with different settings.


- Low for faster, well-scoped tasks

- Medium or High for more complex changes or debugging

- Extra High for long, agentic, reasoning-heavy tasks


To provide context faster, try using speech dictation inside the ChatGPT desktop app to dictate what you want Codex to do rather than typing it.


## Plan first for difficult tasks


If the task is complex, ambiguous, or hard to describe well, ask Codex to plan before it starts coding.


A few approaches work well:


Use Plan mode: For most users, this is the easiest and most effective option. Plan mode lets Codex gather context, ask clarifying questions, and build a stronger plan before implementation. Toggle with `/plan` or Shift+Tab.


Ask Codex to interview you: If you have a rough idea of what you want but aren't sure how to describe it well, ask Codex to question you first. Tell it to challenge your assumptions and turn the fuzzy idea into something concrete before writing code.


Use a PLANS.md template: For more advanced workflows, you can configure Codex to follow a `PLANS.md` or execution-plan template for longer-running or multi-step work. For more detail, see the execution plans guide.


## Make guidance reusable with `AGENTS.md`


Once a prompting pattern works, the next step is to stop repeating it manually. That's where AGENTS.md comes in.


Think of `AGENTS.md` as an open-format README for agents. It loads into context automatically and is the best place to encode how you and your team want Codex to work in a repository.


A good `AGENTS.md` covers:


- repo layout and important directories

- How to run the project

- Build, test, and lint commands

- Engineering conventions and PR expectations

- Constraints and do-not rules

- What done means and how to verify work


The `/init` slash command in the CLI is the quick-start command to scaffold a starter `AGENTS.md` in the current directory. It's a great starting point, but you should edit the result to match how your team actually builds, tests, reviews, and ships code.


You can create `AGENTS.md` files at different levels: a global `AGENTS.md` for personal defaults that sits in `~/.codex`, a repo-level file for shared standards, and more specific files in subdirectories for local rules. If there’s a more specific file closer to your current directory, that guidance wins.


Keep it practical. A short, accurate `AGENTS.md` is more useful than a long file full of vague rules. Start with the basics, then add new rules only after you notice repeated mistakes.


If `AGENTS.md` starts getting too large, keep the main file concise and reference task-specific markdown files for things like planning, code review, or architecture.


When Codex makes the same mistake twice, ask it for a retrospective and update `AGENTS.md`. Guidance stays practical and based on real friction.


## Configure Codex for consistency


Configuration is one of the main ways to make Codex behave more consistently across sessions and surfaces. For example, you can set defaults for model choice, reasoning effort, sandbox mode, approval policy, profiles, and MCP setup.


A good starting pattern is:


- Keep personal defaults in `~/.codex/config.toml` (Settings > Configuration > Open config.toml in the ChatGPT desktop app)

- Keep repo-specific behavior in `.codex/config.toml`

- Use command-line overrides only for one-off situations (if you use the CLI)


`config.toml` is where you define durable preferences such as MCP servers, multi-agent setup, and feature flags. Profile-specific overrides live in separate `$CODEX_HOME/profile-name.config.toml` files.


Codex ships with operating level sandboxing and has two key knobs that you can control. Approval mode determines when Codex asks for your permission to run a command and sandbox mode determines if Codex can read or write in the directory and what files the agent can access.


If you're new to coding agents, start with the default permissions. Keep approval and sandboxing tight by default, then loosen permissions only for trusted repos or specific workflows once the need is clear.


Note that the CLI, IDE extension, and ChatGPT desktop app all share the same configuration layers. Learn more on the sample configuration page.


Configure Codex for your real environment early. Many quality issues are really setup issues, like the wrong working directory, missing write access, wrong model defaults, or missing tools and connectors.


## Improve reliability with testing and review


Don't stop at asking Codex to make a change. Ask it to create tests when needed, run the relevant checks, confirm the result, and review the work before you accept it.


Codex can do this loop for you, but only if it knows what “good” looks like. That guidance can come from either the prompt or `AGENTS.md`.


That can include:


- Writing or updating tests for the change

- Running the right test suites

- Checking lint, formatting, or type checks

- Confirming the final behavior matches the request

- Reviewing the diff for bugs, regressions, or risky patterns


Toggle the diff panel in the ChatGPT desktop app to directly review changes locally. Click on a specific row to provide feedback that gets fed as context to the next Codex turn.


A useful option here is the slash command `/review`, which gives you a few ways to review code:


- Review against a base branch for PR-style review

- Review uncommitted changes

- Review a commit

- Use custom review instructions


If you and your team have a `code_review.md` file and reference it from `AGENTS.md`, Codex can follow that guidance during review as well. This is a strong pattern for teams that want review behavior to stay consistent across repositories and contributors.


Codex shouldn't just generate code. With the right instructions, it can also help test it, check it, and review it.


If you use GitHub Cloud, you can set up Codex to run code reviews for your PRs. At OpenAI, Codex reviews 100% of PRs. You can enable automatic reviews or have Codex reactively review when you @Codex.


## Use MCPs for external context


Use MCPs when the context Codex needs lives outside the repo. It lets Codex connect to the tools and systems you already use, so you don't have to keep copying and pasting live information into prompts.


Model Context Protocol, or MCP, is an open standard for connecting Codex to external tools and systems.


Use MCP when:


- The needed context lives outside the repo

- The data changes frequently

- You want Codex to use a tool rather than rely on pasted instructions

- You need a repeatable integration across users or projects


Codex supports both STDIO and Streamable HTTP servers with OAuth.


In the ChatGPT desktop app, go to Settings > MCP servers to see custom and recommended servers. Often, Codex can help you install the needed servers. All you need to do is ask. You can also use the `codex mcp add` command in the CLI to add your custom servers with a name, URL, and other details.


Add tools only when they unlock a real workflow. Do not start by wiring in every tool you use. Start with one or two tools that clearly remove a manual loop you already do often, then expand from there.


## Turn repeatable work into skills


Once a workflow becomes repeatable, stop relying on long prompts or repeated back-and-forth. Use a skill to package the instructions in a `SKILL.md` file, context, and supporting logic Codex should apply consistently. Skills work across the CLI, IDE extension, and ChatGPT desktop app.


Keep each skill scoped to one job. Start with 2 to 3 concrete use cases, define clear inputs and outputs, and write the description so it says what the skill does and when to use it. Include the kinds of trigger phrases a user would actually say.


Don't try to cover every edge case up front. Start with one representative task, get it working well, then turn that workflow into a skill and improve from there. Include scripts or extra assets only when they improve reliability.


A good rule of thumb: if you keep reusing the same prompt or correcting the same workflow, it should probably become a skill.


Skills are especially useful for recurring jobs like:


- Log triage

- Release note drafting

- PR review against a checklist

- Migration planning

- Telemetry or incident summaries

- Standard debugging flows


The `$skill-creator` skill is the best place to start to scaffold the first version of a skill. Keep the first version local while you iterate. When it's ready to share broadly, package it as a plugin. One of the most important parts of a skill is the description. It should say what the skill does and when to use it.


Personal skills are stored in `$HOME/.agents/skills`, and shared team skills can be checked into `.agents/skills` inside a repository. This is especially helpful for onboarding new teammates.


## Use scheduled tasks for repeated work


Once a workflow is stable, you can schedule Codex to run it in the background for you. In the ChatGPT desktop app, scheduled tasks let you choose the project, prompt, cadence, and execution environment for recurring work.


Create a scheduled task from the Scheduled page. Choose the project, prompt, cadence, and whether the task runs in a dedicated Git worktree or in your local environment. The prompt can invoke skills. Learn more about Git worktrees.


Good candidates include:


- Summarizing recent commits

- Scanning for likely bugs

- Drafting release notes

- Checking CI failures

- Producing standup summaries

- Running repeatable analysis workflows on a schedule


A useful rule is that skills define the method and scheduled tasks define the schedule. If a workflow still needs a lot of steering, turn it into a skill first. Once it's predictable, scheduling it can save time.


Use scheduled tasks for reflection and maintenance, not just execution. Review recent chats, summarize repeated friction, and improve prompts, instructions, or workflow setup over time.


## Organize long-running chats


Chats accumulate context, decisions, and actions over time, so managing them well has a big impact on quality.


The ChatGPT desktop app lets you pin chats and create worktrees. If you use the CLI, these slash commands are especially useful:


- `/experimental` to toggle experimental features and add to your `config.toml`

- `/resume` to resume a saved chat

- `/fork` to create a new chat while preserving the original transcript

- `/compact` when the chat is getting long and you want a summarized version of earlier context. Codex also compacts chats automatically

- `/agent` when you are running parallel agents and want to switch between the active agent thread

- `/theme` to choose a syntax highlighting theme

- `/apps` to use ChatGPT apps directly in Codex

- `/status` to inspect the current session state


Keep one chat per coherent unit of work. If the work is still part of the same problem, staying in the same chat is often better because it preserves the reasoning trail. Fork only when the work truly branches.


Use Codex’s subagent workflows to offload bounded work from the main thread. Keep the main agent focused on the core problem, and use subagents for tasks like exploration, tests, or triage.


## Common mistakes


A few common mistakes to avoid when first using Codex:


- Overloading the prompt with durable rules instead of moving them into `AGENTS.md` or a skill

- Not letting the agent see its work by not giving details on how to best run build and test commands

- Skipping planning on multi-step and complex tasks

- Giving Codex full permission to your computer before you understand the workflow

- Running live tasks on the same files without using Git worktrees

- Scheduling a recurring task before it's reliable manually

- Treating Codex like something you have to watch step by step instead of using it in parallel with your own work

- Using one chat for an entire project instead of one chat per coherent outcome. This leads to bloated context and worse results over time
